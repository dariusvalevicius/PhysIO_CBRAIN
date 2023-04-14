function runPhysio(fmri_file, physio)

% Get fMRI dimensions
fmri_data = double(niftiread(string(fmri_file)));
nifti_header = niftiinfo(fmri_file);


disp('Getting dimensions...');
physio = getDims(physio, nifti_header);


% physio.verbose.fig_output_file = append(fmri_file, '_fig_output.jpg');

% Run physio
% postpone figs
disp('Postponing figure generation...');
[physio, verbose_level, fig_output_file] = postponeFigs(physio);
%disp('fig name:');
%disp(fig_output_file);
% Run PhysIO
disp('Creating PhysIO regressors...');

% try catch main PhysIO process
% if failure, skip to next file (exit function)
try
    physio = tapas_physio_main_create_regressors(physio);
catch err
    fprintf('PhysIO error occured when processing file: %s.\n', fmri_file);
    disp(getReport(err,'extended', 'hyperlinks', 'off'));
   return
end
disp('Complete.');

% generate figures without rendering
disp('Generating and saving figures...');
generateFigs(physio, verbose_level, fig_output_file);


% Run image correction
if(strcmpi(physio.correct, 'yes'))
    disp('Correcting fMRI data...');

    disp('Loading regressors...');
    % Load multiple regressors file
    regressors = load(fullfile(physio.save_dir, 'multiple_regressors.txt'));

    disp('Running Correction...');
    % Run correction
    % Correction algorithm adapted from Catie Chang

    % Get raw variance
    var_raw = var(fmri_data, 0, 4);

    disp('Arranging label...');
    % Arrange data label
    Y = reshape(fmri_data, physio.x_size*physio.y_size*physio.scan_timing.sqpar.Nslices, physio.scan_timing.sqpar.Nscans)';
    t = (1:physio.scan_timing.sqpar.Nscans)';

    % clear fmri_data for memory
    clear fmri_data

    disp('Setting up design matrix...');
    % Set design matrix
    % Uses intercept (1), time, time squared, and PhysIO regressors
    XX = [t, t.^2, regressors];
    XX = [ones(size(XX,1),1), zscore(XX)];

    disp('Regressing...');
    % Compute model betas and subtract beta-weighted regressors from input fmri
    % data to correct
    Betas = XX\Y;
    Y_corr = Y - XX(:,4:end)*Betas(4:end,:);
    clear Y % For memory saving

    disp('Correcting...');
    fmri_corrected = reshape(Y_corr', physio.x_size, physio.y_size, physio.scan_timing.sqpar.Nslices, physio.scan_timing.sqpar.Nscans);
    clear Y_corr % For memory saving

    disp('Computing pct var reduced...');
    % Compute pct var reduced (3D double)
    %var_raw = var(fmri_data, 0, 4); Moved up so fmri_data can be cleared
    %before correction
    var_corrected = var(fmri_corrected, 0, 4);
    pct_var_reduced = (var_raw - var_corrected) ./ var_raw;


    disp('Correction complete.');
    fprintf('Maximum variance reduced(diagnostic): %d\n', max(pct_var_reduced, [], 'all'));

    disp('Typecasting data...');
    data_type = nifti_header.Datatype;
    fmri_corrected_typecast = reshape(cast(fmri_corrected(:), data_type), size(fmri_corrected));
    %fmri_corrected_typecast = reshape(fmri_corrected_typecast, size(fmri_corrected));
    clear fmri_corrected % Memory

    disp('Writing niftis...');
    
    fmri_corrected_filename = createOutFilename(physio, fmri_file);
    fmri_corrected_fullfile = string(fullfile(physio.save_dir_fmri, fmri_corrected_filename));
    % disp(fmri_corrected_fullfile);
    
    niftiwrite(fmri_corrected_typecast, fmri_corrected_fullfile, nifti_header); % Write fmri output file
    
    pvr_filename = fullfile(physio.save_dir, 'pct_var_reduced.nii');
    niftiwrite(pct_var_reduced, pvr_filename); % Write pct_var_reduced file

    disp('Compressing...');
    gzip(fmri_corrected_fullfile);
    delete(fmri_corrected_fullfile);
    gzip(pvr_filename);
    delete(pvr_filename);

    disp('Complete.');
end

% Get HR and BR [DISABLED due to inconsistent behaviour]
%[heartrate_hz, heartrate_bpm, breathing_hz, breathing_bpm] = estimateBrHr(physio);
%t = table(heartrate_hz, heartrate_bpm, breathing_hz, breathing_bpm);
%writetable(t, fullfile(physio.save_dir, 'hr_br.txt'), 'Delimiter', '\t');

end

function fmri_corrected_filename = createOutFilename(physio, fmri_file)

% Create output files
[~,fmri_name_only,ext] = fileparts(fmri_file);
if contains(fmri_name_only, '_bold.nii')
    fmri_name_models = extractBefore(append(fmri_name_only, ext), '_bold.nii');
else
    fmri_name_models = extractBefore(append(fmri_name_only, ext), '.nii');
end

fmri_name_models = append(fmri_name_models, '_corrected');

% Append model names

if physio.model.retroicor.include
    fmri_name_models = append(fmri_name_models, '-retroicor');
end
if physio.model.rvt.include
    fmri_name_models = append(fmri_name_models, '-rvt');
end
if physio.model.hrv.include
    fmri_name_models = append(fmri_name_models, '-hrv');
end
if physio.model.noise_rois.include
    fmri_name_models = append(fmri_name_models, '-noiseRois');
end
if physio.model.movement.include
    fmri_name_models = append(fmri_name_models, '-movement');
end

fmri_corrected_filename = append(fmri_name_models, '_bold.nii');

end

function physio = getDims(physio, nifti_header)

% Get fmri file dimenions from header
physio.x_size = nifti_header.ImageSize(1);
physio.y_size = nifti_header.ImageSize(2);
physio.scan_timing.sqpar.Nslices = nifti_header.ImageSize(3);
physio.scan_timing.sqpar.Nscans = nifti_header.ImageSize(4);
physio.scan_timing.sqpar.TR = nifti_header.PixelDimensions(4);
if strcmp(physio.scan_timing.sqpar.onset_slice, '<UNDEFINED>')
    physio.scan_timing.sqpar.onset_slice = physio.scan_timing.sqpar.Nslices / 2;
end

end


function [physio, verbose_level, fig_output_file] = postponeFigs(physio)

% postpone figure generation in first run - helps with compilation
% relies on certain physio.verbose parameters - see setDefaults() below
if isfield(physio, 'verbose') && isfield(physio.verbose, 'level')
     verbose_level = physio.verbose.level;
     physio.verbose.level = 0;
     if isfield(physio.verbose, 'fig_output_file') && ~strcmp(physio.verbose.fig_output_file, '')
         fig_output_file = physio.verbose.fig_output_file;
     else
         fig_output_file = 'PhysIO_output.jpg'; 
     end    
else
  verbose_level = 0;
end 

end

function generateFigs(physio, verbose_level, fig_output_file)
    
% Build figures
if verbose_level
  physio.verbose.fig_output_file = fig_output_file; % has to reset, the old value is distorted
  physio.verbose.level = verbose_level;
  tapas_physio_review(physio);
end

end

