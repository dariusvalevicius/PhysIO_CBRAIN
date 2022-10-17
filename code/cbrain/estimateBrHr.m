function [hr_hz, hr_bpm, br_hz, br_bpm] = estimateBrHr(physio)
%% Parse inputs
p = inputParser;
addRequired(p, 'physio', @isstruct);
parse(p, physio);
physio = p.Results.physio;

disp("Estimating breathing rate and heart rate...")


%% Load physlogfile

disp("Loading physlogfile...")

physlogfile = 'none';
cardiac = 0;
respiration = 0;

if isfield(physio.log_files, 'cardiac')
    physlogfile = physio.log_files.cardiac;
    cardiac = 1;
end
if isfield(physio.log_files, 'respiration')
    physlogfile = physio.log_files.respiration;
    respiration = 1;
end
if cardiac == 0 || respiration == 0
    msg = 'Error: No physlogfile found in physio struct.';
    error(msg);
end

% n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);

if strcmp(physio.log_files.vendor, 'Philips')
    % Load physiological logfile and get relevant data
    
    % logfile = read_physio_orig(physlogfile);
    
    data = readPhilipsPhyslog(physlogfile);
    
   
    phys_data = table(data.ppu, data.resp, data.mark, ...
        'VariableNames', {'ppu', 'resp', 'mark'});

    % Subset data to mark start and mark end

    % Get end marker and find start marker from scanning parameters
    % No start marker in the logfile apparently. This is the same procedure as
    % new_analyse_resp_HR_ketamine.m

    n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);
    
    mark_end = int64(find(phys_data.mark == 20, 1, 'last'));
    mark_start = int64(mark_end - (n_samples));

    phys_data_subset = phys_data(mark_start:mark_end,:);
    
    
    if cardiac
        cardiac_wave = phys_data_subset.ppu;
    end
    if respiration
        resp_wave = phys_data_subset.resp;
    end

elseif strcmp(physio.log_files.vendor, 'BIDS')
            
    if ~contains(physlogfile, '.tsv')
        msg = '.tsv file not found!';
        error(msg);
    end
    
    header = getBidsPhyslogSidecar(physlogfile);
    
    if contains(physlogfile, '.gz')
        gunzip(physlogfile, 'temp');
        [~,tsv_filename,~] = fileparts(physlogfile);
        logfile = load(fullfile('temp', tsv_filename));
        status = rmdir('temp', 's');
        if ~status
            msg = 'Error removing temp directory.';
            error(msg);
        end
    else
        logfile = load(physlogfile);
    end
    
    tsv_table = array2table(logfile, 'VariableNames', header.Columns);
    %disp(head(tsv_table))
    
    %physio.log_files.sampling_interval = header.SamplingFrequency;
    n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);
    
    mark_end = int64(find(tsv_table.trigger == 1, 1, 'last'));
    mark_start = int64(mark_end - (n_samples));

    phys_data_subset = tsv_table(mark_start:mark_end,:);
    
    if cardiac
        cardiac_wave = phys_data_subset.cardiac;
    end
    if respiration
        resp_wave = phys_data_subset.respiratory;
    end
end


%% Get highest powered frequency

disp("Analyzing time series..")

if respiration
    br_hz = getMaxFreq(resp_wave, physio.log_files.sampling_interval);
    br_bpm = br_hz * 60;
end

%%
if cardiac
    hr_hz = getMaxFreq(cardiac_wave, physio.log_files.sampling_interval);
    hr_bpm = hr_hz * 60;
end

disp("Done estimating BR and HR.")


end


function [max_freq] = getMaxFreq(waveform, sampling_rate)

% Gets the highest-powered frequency of the fourrier transform.
% Frequency, amplitudue, and sampling rate are halved to avoid
% spikes at high frequencies (peaks at ~sampling rate Hz).

spectral_amplitude = fft(waveform);
spectral_amplitude = spectral_amplitude(1:round(0.5*length(spectral_amplitude)));

frequency = (0:length(spectral_amplitude)-1)*(0.5*(1/sampling_rate))/length(spectral_amplitude);

[~, i] = max(spectral_amplitude);
max_freq = frequency(i);
end
