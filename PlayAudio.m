function PlayAudio(fName)
%PLAYAUDIO  - load & play audio file (MARTA stimulus handler)

if strcmpi(fName,'ABORT'); return; end;
try,
	[s,sr] = wavread(fName);
	sound(s,sr);
catch,
	fprintf('Warning:  %s not found\n', fName);
end;
