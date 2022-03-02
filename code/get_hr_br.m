function [hr_hz, hr_bpm, br_hz, br_bpm] = get_hr_br(physio)
%% Parse inputs
p = inputParser;
addRequired(p, 'physio', @isstruct);
parse(p, physio);
physio = p.Results.physio;


%% Load physlogfile

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


%disp(physio.scan_timing.sqpar.Nscans);
%disp(physio.scan_timing.sqpar.TR);
%disp(physio.log_files.sampling_interval);

%disp(size(physio.scan_timing.sqpar.Nscans));
%disp(size(physio.scan_timing.sqpar.TR));
%disp(size(physio.log_files.sampling_interval));

% n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);



switch physio.log_files.vendor
    case 'Philips'
        % Load physiological logfile and get relevant data
        
        % logfile = read_physio_orig(physlogfile);
        
        data = read_philips_physlogfile(physlogfile);
        
       
        phys_data = table(data.ppu, data.resp, data.mark, ...
            'VariableNames', {'ppu', 'resp', 'mark'});

        % Subset data to mark start and mark end

        % Get end marker and find start marker from scanning parameters
        % No start marker in the logfile apparently. This is the same procedure as
        % new_analyse_resp_HR_ketamine.m

        n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);
        
        mark_end = int64(find(phys_data.mark == 20, 1, 'last'));
        %disp(mark_end);
        mark_start = int64(mark_end - (n_samples));
        %disp(mark_start);

        phys_data_subset = phys_data(mark_start:mark_end,:);
        
        
        if cardiac
            cardiac_wave = phys_data_subset.ppu;
        end
        if respiration
            resp_wave = phys_data_subset.resp;
        end

        
    case 'BIDS'
        
        if ~contains(physlogfile, '.tsv')
            msg = '.tsv file not found!';
            error(msg);
        end
        
        header = get_bids_physlogfile_sidecar(physlogfile);
        
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
        
        physio.log_files.sampling_interval = header.SamplingFrequency;
        n_samples = physio.scan_timing.sqpar.Nscans * physio.scan_timing.sqpar.TR * (1 / physio.log_files.sampling_interval);
        
        mark_end = int64(find(tsv_table.trigger == 1, 1, 'last'));
        %disp(mark_end);
        mark_start = int64(mark_end - (n_samples));
        %disp(mark_start);

        phys_data_subset = tsv_table(mark_start:mark_end,:);
        
        if cardiac
            cardiac_wave = phys_data_subset.cardiac;
        end
        if respiration
            resp_wave = phys_data_subset.respiratory;
        end
end


%% Get highest powered frequency

if respiration
    br_hz = get_max_freq(resp_wave, physio.log_files.sampling_interval);
    br_bpm = br_hz * 60;
end

%disp(resp_max);
%%
if cardiac
    hr_hz = get_max_freq(cardiac_wave, physio.log_files.sampling_interval);
    hr_bpm = hr_hz * 60;
end

%disp(cardiac_max);


end


function [max_freq] = get_max_freq(waveform, sampling_rate)

% Gets the highest-powered frequency of the fourrier transform.
% Frequency, amplitudue, and sampling rate are halved to avoid
% spikes at high frequencies (peaks at ~sampling rate Hz).

spectral_amplitude = fft(waveform);
spectral_amplitude = spectral_amplitude(1:round(0.5*length(spectral_amplitude)));

frequency = (0:length(spectral_amplitude)-1)*(0.5*(1/sampling_rate))/length(spectral_amplitude);

%plot(frequency, abs(spectral_amplitude));

[~, i] = max(spectral_amplitude);
max_freq = frequency(i);
%disp(dominant_freq);
end