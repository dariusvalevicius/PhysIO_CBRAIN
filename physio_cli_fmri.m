function physio_cli_fmri(in_dir, save_dir, fmri_data, correct, varargin)   
%% A command line wrapper for the main entry function 
% tapas_physio_main_create_regressors of the Physio (for Philips equipment)
% This version target mostly Philips equipment 
% and enables compilation and cbrain integration of physio.
% User may dump his existing matlab json 
% physio structure into such file. Parameters can be set from
% an exisiting example of config, provided by toolset. The command line
% parameters have highest priority, than ones from the json file.
% The main purpose of this script is integraton to CBRAIN yet it 
% can be used with other frameworks as well, or compilation so tool can be used
% on machine without MATLAB
%
% NOTE: All physio-structure can be specified previous to
%       running this function, e.g model.retroir.c, 3, save_dir - prefix
%       for resulting folder and in_dir are positional parameters, absent 
%        in the original physio.
%
% IN 
%   correct          choose whether to correct fMRI data or just produce
%                    regressors
%   fmridata         fmri run to be corrected, in .nii.gz format
%
% EXAMPLES
%
%   phiwrap('myfiles_dir', 'results',...
%            'paramfile',   'allotherparams.json',...
%            'model.retroicor.degree.c', 3, ...
%            'fmridata', 'fmri_scan_sub01.nii.gz') 
%
% REFERENCES
%
% CBRAIN        www.cbrain.com 
% RETROICOR     regressor creation based on Glover et al. 2000, MRM 44 and
%               Josephs et al. 1997, ISMRM 5, p. 1682
%               default model order based on Harvey et al. 2008, JMRI 28
% RVT           (Respiratory volume per time) Birn et al. 2008, NI 40
% HRV           (Heart-rate  variability) regressor creation based on
%               Chang et al2009, NI 44
%
% See also tapas_physio_new

% Author:    Serge Boroday
% Created:   2021-03-16
% Copyright: McGill University
%
% Modified by:  Darius Valevicius
% Date:         2021-06-22
%
% The original tool is by Institute for Biomedical Engineering, 
%               University of Zurich and ETH Zurich.
%
% This file is a wrapper for TAPAS PhysIO Toolbox, Phillips equipment only


SEPARATOR = '\s*[,\s]'; % the separator for vector/interval inputs - coma and/or white space
DOT = '__'; % to use MATLAP argument parser the dots are replaced with doubleunderscore

disp(pwd);
disp(struct2table(dir()));


%% Input Parser

p = inputParser;
p.KeepUnmatched = true;

addRequired(p, 'in_dir');
addRequired(p, 'save_dir');

%fmri_data = fullfile(in_dir, fmri_data);
addRequired(p, 'fmri_data');   %, @isfile);
addRequired(p, 'correct');

parse(p, in_dir, save_dir, fmri_data, correct);

fmri_data = fullfile(in_dir, fmri_data);

%% Create default parameter structure with all fields
physio = tapas_physio_new();

physio = setDefaults(physio);

%% Set specified parameters (save_dir and varargin)

physio.save_dir = save_dir;

varargin(1:2:end) = strrep(varargin(1:2:end), '.', '__'); 
fields = [varargin(1:2:end); varargin(2:2:end)];

for i = 1:size(fields, 2)
    field_value = fields{2, i};
    if (~isnan(str2double(field_value)))
        field_value = str2double(field_value);
    end
    fieldseq = regexp(fields{1, i}, '__', 'split');
    physio = setfield(physio, fieldseq{:}, field_value);
end

physio.log_files.cardiac = fullfile(in_dir, physio.log_files.cardiac);
physio.log_files.respiration = fullfile(in_dir, physio.log_files.respiration);



%% postpone figure generation in first run - helps with compilation

if isfield(physio, 'verbose') && isfield(physio.verbose, 'level')
     verbose_level = physio.verbose.level;
     physio.verbose.level = 0;
     if isfield(physio, 'fig_output_file')
         fig_output_file = physio.verbose.fig_output_file;
     else
         fig_output_file = 'PhysIO_output.png'; 
     end    
else
  verbose_level = 0;
end 


%% Run physiological recording preprocessing and noise modeling

disp('Creating PhysIO regressors...');
physio = tapas_physio_main_create_regressors(physio);


%% Build figures
if verbose_level
  physio.verbose.fig_output_file = fig_output_file; % has to reset, the old value is distorted
  physio.verbose.level = verbose_level;
  tapas_physio_review(physio);
end


%% Unzip .nii file

disp('PhysIO complete.');
fprintf('PhysIO save dir: %s\n', physio.save_dir);

disp('Unzipping fMRI data...');
fmrigz_string = convertCharsToStrings(fmri_data);

% Extract .nii from .gz
gunzip(fmrigz_string);

% Get header from extracted .nii file
fmrifilename = extractBetween(fmrigz_string, 1, strlength(fmrigz_string)-3);

%% Perform correction

if(strcmpi(correct, 'yes'))

    disp('Correcting fMRI data...');

    fmri_data = double(niftiread(fmrifilename));
    regressors = load(strcat(physio.save_dir, '/multiple_regressors.txt'));

    [fmri_corrected, pct_var_reduced] = correct_fmri(fmri_data, regressors);

    disp('Correction complete.');
    fprintf('Maximum variance reduced(diagnostic): %d\n', max(pct_var_reduced, [], 'all'));

    disp('Writing and zipping niftis...');

    niftiwrite(fmri_corrected, strcat(physio.save_dir, '/fmri_corrected.nii'));
    niftiwrite(pct_var_reduced, strcat(physio.save_dir, '/pct_var_reduced.nii'));
    %gzip(strcat(physio.save_dir, '/fmri_corrected.nii'));

    disp('Complete.');

end



end


function [S] = merge_struct(S_1, S_2)
% update the first struct with values and keys of the second and returns the result
% deep update, merges substructrues recursively, the values from the first
% coinside

f = fieldnames(S_2);

for i = 1:length(f)
    if isfield(S_1, f{i}) && isstruct(S_1.(f{i})) && isstruct(S_2.(f{i}))
        S_1.(f{i}) = merge_struct(S_1.(f{i}), S_2.(f{i}));
    else   
        S_1.(f{i}) = S_2.(f{i});
    end        
end
S = S_1;
end


function [fmri_corrected, pct_var_reduced] = correct_fmri(fmri_data, regressors)

% Get dimensions
x = size(fmri_data);
nslices = x(3);
nframes = x(4);

% Arrange data label
Y = reshape(fmri_data, x(1)*x(2)*nslices, nframes)';
t = (1:nframes)';

% Set design matrix
% Uses intercept (1), time, time squared, and PhysIO regressors
XX = [t, t.^2, regressors];
XX = [ones(size(XX,1),1), zscore(XX)];

% Compute model betas and subtract beta-weighted regressors from input fmri
% data to correct
Betas = XX\Y;
Y_corr = Y - XX(:,4:end)*Betas(4:end,:);
fmri_corrected = reshape(Y_corr', x(1), x(2), nslices, nframes);

% Compute pct var reduced (3D double)
var_raw = var(fmri_data, 0, 4);
var_corrected = var(fmri_corrected, 0, 4);
pct_var_reduced = (var_raw - var_corrected) ./ var_raw;

mask = createMask(fmri_data);
niftiwrite(mask, 'mask_test.nii');
pct_var_reduced = pct_var_reduced .* mask;


end

function [mask] = createMask(fmri_data)

    fmri_avg = mean(fmri_data, 4);
    fmri_grand_mean = mean(fmri_avg, 'all');

    mask = ones(size(fmri_avg));

    mask(fmri_avg < (0.8 * fmri_grand_mean)) = 0;

end

function [physio] = setDefaults(physio)

physio.save_dir = {'physio_out'};
physio.log_files.vendor = 'Philips';
physio.log_files.cardiac = '<UNDEFINED>';
physio.log_files.respiration = '<UNDEFINED>';
physio.log_files.relative_start_acquisition = 0;
physio.log_files.align_scan = 'last';
physio.scan_timing.sqpar.Nslices = '<UNDEFINED>';
physio.scan_timing.sqpar.TR = '<UNDEFINED>';
physio.scan_timing.sqpar.Ndummies = '<UNDEFINED>';
physio.scan_timing.sqpar.Nscans = '<UNDEFINED>';
physio.scan_timing.sqpar.onset_slice = '<UNDEFINED>';
physio.scan_timing.sync.method = 'nominal';
physio.preproc.cardiac.modality = 'ECG';
physio.preproc.cardiac.filter.include = false;
physio.preproc.cardiac.filter.type = 'butter';
physio.preproc.cardiac.filter.passband = [0.3 9];
physio.preproc.cardiac.initial_cpulse_select.method = 'auto_matched';
physio.preproc.cardiac.initial_cpulse_select.max_heart_rate_bpm = 90;
physio.preproc.cardiac.initial_cpulse_select.file = 'initial_cpulse_kRpeakfile.mat';
physio.preproc.cardiac.initial_cpulse_select.min = 0.4;
physio.preproc.cardiac.posthoc_cpulse_select.method = 'off';
physio.preproc.cardiac.posthoc_cpulse_select.percentile = 80;
physio.preproc.cardiac.posthoc_cpulse_select.upper_thresh = 60;
physio.preproc.cardiac.posthoc_cpulse_select.lower_thresh = 60;
physio.model.orthogonalise = 'none';
physio.model.censor_unreliable_recording_intervals = false;
physio.model.output_multiple_regressors = 'multiple_regressors.txt';
physio.model.output_physio = 'physio.mat';
physio.model.retroicor.include = true;
physio.model.retroicor.order.c = 3;
physio.model.retroicor.order.r = 4;
physio.model.retroicor.order.cr = 1;
physio.model.rvt.include = false;
physio.model.rvt.delays = 0;
physio.model.hrv.include = false;
physio.model.hrv.delays = 0;
physio.model.noise_rois.include = false;
physio.model.noise_rois.thresholds = 0.9;
physio.model.noise_rois.n_voxel_crop = 0;
physio.model.noise_rois.n_components = 1;
physio.model.noise_rois.force_coregister = 1;
physio.model.movement.include = false;
physio.model.movement.order = 6;
physio.model.movement.censoring_threshold = 0.5;
physio.model.movement.censoring_method = 'FD';
physio.model.other.include = false;
physio.verbose.level = 2;
physio.verbose.process_log = cell(0, 1);
physio.verbose.fig_handles = zeros(1, 0);
physio.verbose.use_tabs = false;
physio.verbose.show_figs = true;
physio.verbose.save_figs = false;
physio.verbose.close_figs = false;
physio.ons_secs.c_scaling = 1;
physio.ons_secs.r_scaling = 1;

end


