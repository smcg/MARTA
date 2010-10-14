%function [fmt,bw] = snackmex(s,sr)
% Returns the formants and associated bandwidths of the signal (s) at
% sampling rate (sr). Requirements: abs(s) >=1
%
%function [fmt,bw] = snackmex(s,sr,'PARAM1',VAL1,'PARAM2',VAL2,...)
% This functional form allows modification of the parameters listed below.
% The default values are from the ESPS/Wavesurfer code.
%   start         : starting position in waveform (default: 0 in samples)
%   end           : ending position in waveform (default: length of s in samples)
%   frameinterval : time between successive frames (default: 0.01 s);
%   window        : duration of analysis window (default: .049 s)
%   wintype       : window type: 0=rectangular; 1=Hamming; 2=cos**4 3=hanning  (default: 1)
%   preemp        : preemphasis factor (default: 0.7)
%   nform         : Number of formants (default: 4)
%   lpcord        : LPC order (default: 12)
%   lpctype       : ??? (default: 0)
%   dsfreq        : Downsampling frequency (default: 12000)
%   nomf1         : Nominal F1 frequency (default: -10)
