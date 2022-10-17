function physioWrapper(use_case, fmri_in, out_dir, correct, varargin)   
%% A command line wrapper for the main entry function 
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
%   in_dir           Folder containing input data (logfiles and fMRI data)
%                    or fmri file for manual input
%   out_dir          Name of folder for outputs
%   use_case         Specifies what input directory structure to expect
%   correct          Choose whether to correct fMRI run or just produce
%                    regressors
%
% OUT
%   multiple_regressors.txt       File containing regressors generated by
%                                 PhysIO
%   *.png                         Diagnostic plots from PhysIO
%   fmri_corrected.nii            If 'correct' is set to 'yes', returns
%                                 corrected fMRI image
%   pct.var.reduced.nii           3D double representing the pct var
%                                 reduced by the regressors at each voxel
%
% EXAMPLES
%
%   physio_cli_fmri('input_folder',...
%                   'output_folder',...
%                   'Single_run',...
%                   'yes',...
%                   'param_1', 'value_1',...
%                   'param_2', 'value_2',...
%                   'param_3', 'value_3') 
%
%
% MALTAB TOOL COMPILATION
%
% Example command: mcc -m physioWrapper.m -a ./code/*.m -d standalone -o physio_cbrain
%
% DOCKER CONTAINER
%
% Example command: compiler.package.docker('standalone/physio_cbrain', 'standalone/requiredMCRProducts.txt', 'ImageName', 'physio_cbrain', 'DockerContext', 'docker', 'ExecuteDockerBuild', 'off')
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

% Authors:    Serge Boroday, Darius Valevicius
% Created:   2021-03-16
% Copyright: McGill University
%
%
% The original tool is by Institute for Biomedical Engineering, 
%               University of Zurich and ETH Zurich.
%
% This file is a wrapper for TAPAS PhysIO Toolbox

%% Input Parser

p = inputParser;
p.KeepUnmatched = true;


addRequired(p, 'use_case');
addRequired(p, 'fmri_in');
addRequired(p, 'out_dir');
addRequired(p, 'correct');

parse(p, use_case, fmri_in, out_dir, correct);

% Debugging: display inputs

%input_msg = ['Use case: ',use_case,', In dir: ',in_dir,', Out dir: ',out_dir,', Fmri file: ',fmri_file,', Correct: ',correct];

%disp(input_msg);


%% Start diary

diary_file = fullfile(out_dir, 'derivatives', 'PhysIO', 'cbrain_physio.log');
disp(diary_file);
mkdir(fullfile(out_dir, 'derivatives', 'PhysIO'));

[fid, msg] = fopen(diary_file, 'w');
disp(msg);
fprintf(fid, 'Log of PhysIO on CBRAIN\n');
fprintf(fid, append(string(datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z')), '\n'));
fclose(fid);
diary(diary_file);

%% Create default parameter structure with all fields
physio = tapas_physio_new();

physio = setStructDefaults(physio);

physio.correct = correct;

%% Set specified parameters (save_dir and varargin)

fields = parseNonPosArgs(varargin);
    
physio = setStructFields(physio, fields);


%% Set fmri_file and in_dir values (hackey workaround to CBRAIN interface problem)
% Problem description: File type inputs in CBRAIN cannot have default
% values. Therefore they can't be passed as positional params, and have to
% be extracted from varargin.

% Update 17/01/2022:
% Merged fmri_file and in_dir inputs into single argument to facilitate
% output folder naming within the boutiques descriptor.

in_dir = 'none';
fmri_file = 'none';

switch use_case
    case 'bids_directory'
        in_dir = fmri_in;
    case 'manual_input'
        fmri_file = fmri_in;
end


%% Scan subject directory and perform correction on each fMRI file

phys_ext = '';
%cardiac_marker = '';
%resp_marker = '';

switch physio.log_files.vendor
    case 'BIDS'
        phys_ext = '.tsv';
    case 'Philips'
        phys_ext = '.log';
end

if strcmp(use_case, 'bids_directory')
        
    % From input/subject folder
    % Get every nifti in func
    % and associated physlogfiles
    % based on vendor
    %   BIDS: .tsv.gz
    %   Philips: .log
    %   
    % Currently implemented for BIDS and Philips only    
    
    % Get all bold files
    bold_filelist = dir(fullfile(in_dir, '**/*bold.nii*'));
    %disp(bold_filelist)
    % Get all physio files
    physio_filelist = dir(fullfile(in_dir, sprintf('**/*physio%s*', phys_ext)));
    
    % loop through bold files
    for i = 1:numel(bold_filelist)
        file = bold_filelist(i);
        filename = file.name;
        b_filepath = file.folder;
        
        fprintf('\n\nProcessing file: %s\n', filename);
        
        % set fmri file
        fmri_file = fullfile(b_filepath, filename);
        
        % get subject folder and session tokens
        subject_folder = append('sub-', extractBetween(filename, 'sub-', '_'));
        session = '';
        if contains(filename, '_ses-')
            session = append('ses-', extractBetween(filename, 'ses-', '_'));
        end
       
        % create save file name
        save_filename = insertBefore(filename, 'bold', 'corrected-physio_');
        fmri_name = extractBefore(save_filename, '.nii');
        physio.save_dir = fullfile(out_dir, 'derivatives', 'PhysIO', subject_folder, session, 'func', fmri_name);
        physio.save_dir_fmri = fullfile(out_dir, 'derivatives', 'PhysIO', subject_folder, session, 'func');
        % mkdir(physio.save_dir);
    
        % loop through physio files
        for j=1:numel(physio_filelist)
            p_file = physio_filelist(j);
            p_filename = p_file.name;
            p_filepath = p_file.folder;
            if contains(p_filename, extractBefore(filename, '_bold'))
                logfile = fullfile(p_filepath, p_filename);
            end
        end
        
        [has_cardiac, has_resp] = has_cardiac_resp(physio.log_files.vendor, logfile);
        
        if has_cardiac
            physio.log_files.cardiac = logfile;
        end
        if has_resp
            physio.log_files.respiration = logfile;
        end
        
        % Refresh some params (they would stack otherwise)
        % NOTE: the fact that this is needed may signal that other
        % parameters may break/stack when physio is looped. Keep an eye out,
        % may need to recode
        physio.model.output_physio = 'physio.mat';
        physio.model.output_multiple_regressors = 'multiple_regressors.txt';
        
        runPhysio(fmri_file, physio);
    end 


elseif strcmp(use_case, 'manual_input')
        
    % No fmri input error
    if (strcmp(fmri_file, 'none'))
        msg = 'Manual input: No fMRI file was input.';
        error(msg);
    end
    
    % No logfile input error
    % also handles combined input if individual carfiles are not given
    if (~isfile(physio.log_files.cardiac) && ~isfile(physio.log_files.respiration))
        try 
            isfile(physio.log_files.cardiac_respiration);
            physio.log_files.cardiac = physio.log_files.cardiac_respiration;
            physio.log_files.respiration = physio.log_files.cardiac_respiration;
        catch
            msg = append('Manual input: Log file(s) are invalid. Input at least one logfile.');
            error(msg);
        end
    end

    physio.save_dir = out_dir;
    runPhysio(fmri_file, physio);

else
        msg = 'No valid use-case selected.';
        error(msg);
end

disp('PhysIO on CBRAIN has completed.')

diary off;

end


function fields = parseNonPosArgs(varargin)

varargin = varargin{1};

%celldisp(varargin)
% Convert decimal char to double underscore for struct parsing
try    
    for i = 1:2:length(varargin)
        varargin{i} = strrep(varargin{i}, '.', '__');
    end
catch
    msg = sprintf("Error strrepping varargin on argument %s", varargin{1,i});
    error(msg);
end

% Fold varargin into 2 rows, fields and values
try
    fields = cell(2,length(varargin) / 2);
    fields(1,:) = varargin(1:2:end);
    fields(2,:) = varargin(2:2:end);
catch ME
   if (strcmp(ME.identifier,'MATLAB:catenate:dimensionMismatch'))
      msg = ['Varargin: Dimension mismatch occurred: First argument has ', ...
            num2str(size(varargin(1:2:end),2)),' columns while second has ', ...
            num2str(size(varargin(2:2:end),2)),' columns.'];
        causeException = MException('MATLAB:myCode:dimensions',msg);
        ME = addCause(ME,causeException);
   end
   rethrow(ME)
end 

end

function physio = setStructFields(physio, fields)

%celldisp(fields)

% Set params in physio structure from varargin
for i = 1:size(fields, 2)
    
    field_value = fields{2, i};
    
    if (~isnan(str2double(field_value)))
        field_value = str2double(field_value);
    elseif (strcmp(field_value, 'yes') || strcmp(field_value, 'true'))
        field_value = 1;
    elseif (strcmp(field_value, 'no') || strcmp(field_value, 'false'))
        field_value = 0;
    end
    
    fieldseq = regexp(fields{1, i}, '__', 'split');
    physio = setfield(physio, fieldseq{:}, field_value);
end

end


function [has_cardiac, has_resp] = has_cardiac_resp(vendor, physlogfile)
    
has_cardiac = 0;
has_resp = 0;

switch vendor
    case 'BIDS'      
        header = getBidsPhyslogSidecar(physlogfile);
        
        if any(strcmp(header.Columns, 'cardiac'))
            has_cardiac = 1;
        end
        if any(strcmp(header.Columns, 'respiratory'))
            has_resp = 1;
        end
        
    case 'Philips'
        
        logfile = readPhilipsPhyslog(physlogfile);
        
        if any(strcmp(logfile.Properties.VariableNames, 'ppu'))
            has_cardiac = 1;
        end
        if any(strcmp(logfile.Properties.VariableNames, 'resp'))
            has_resp = 1;
        end
    otherwise
        msg = append('BIDS subject folder mode does not work with vendor ', vendor);
        error(msg);
end
            
end

