function DumpProtocol(t, fName)
%DUMPPROTOCOL  - dump trials to protocol file
%
%	usage:  DumpProtocol(t, fName)
%
% writes trial list T to output FNAME in expt protocol format

% mkt 07/09

if nargin < 2,
	eval('help DumpProtocol');
	return;
end;

try,
	[p,f,e] = fileparts(fName);
	if isempty(e), fName = fullfile(p,[f,'.txt']); end;
	fid = fopen(fName, 'wt');
	for k = 1 : length(t),
		if isempty(t(k).FNAME),
			fprintf(fid,'\n%s\n', t(k).PROMPT);
		else,
			fprintf(fid,'%-53s%s\n', t(k).FNAME, t(k).PROMPT);
		end;
	end;
catch,
	error('error attempting to write %s', fName);
end;
fclose(fid);
fprintf('wrote %s\n', fName);
