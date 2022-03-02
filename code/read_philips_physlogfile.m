function [logfile] = read_philips_physlogfile(physlogfile)

fid = fopen(physlogfile, 'r');

current_line = fgetl(fid);
while contains(current_line, '##')
    current_line = fgetl(fid);
end

if contains(current_line, '# ')
    var_names = strsplit(current_line, ' ');
    var_names = var_names(2:end);

    values = fread(fid, Inf);
    fclose(fid);

    fid = fopen('physlogfile_values.txt', 'w');
    fwrite(fid, values);
    fclose(fid);

    logfile = readtable('physlogfile_values.txt', 'Delimiter', ' ', ...
        'ConsecutiveDelimitersRule', 'join');
    logfile.Properties.VariableNames = var_names;
else
    msg = "Error reading physlogfile. Check file header.";
    error(msg)
end

end