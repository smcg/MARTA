function rectest(doDec)
%RECTEST  - test DAQ timer/recording interaction
%
% specify nonzero DODEC for decimation

if nargin < 1 || isempty(doDec), doDec = 0; end;

%% params
dur = 10;
sr = 48000;

%% init DAQ object
info = daqhwinfo('winsound');
AI = eval(info.ObjectConstructorName{1});
addchannel(AI, 1);
sr = setverify(AI,'sampleRate',sr);
AI.BufferingMode = 'auto';
AI.TriggerType = 'manual';
AI.TriggerRepeat = 0;
AI.LogFileName = 'junk.daq';
AI.LoggingMode = 'Disk';
%AI.LoggingMode = 'Disk&Memory';
nSamps = round(dur * sr);
AI.SamplesPerTrigger = nSamps;
set(AI,'StopFcn',@Finalize);

%% init plotting
fh = figure('doubleBuffer','on');
cla;
if doDec,
	x = linspace(0,dur,2*ceil(nSamps/200));
	y = zeros(1,2*ceil(nSamps/200));
else,
	x = linspace(0,dur,nSamps);
	y = zeros(nSamps,1);
end;
plot(x,y,'color','g','linestyle',':');
lh = line(x,NaN*y,'eraseMode','none','hittest','off','clipping','off');
set(lh, 'userData', [0;0;doDec]);			% sampsAcquired, decimated tail, doDec
set(gca,'xlim',[0 dur],'ylim',[-1 1],'drawmode','fast', ...
		'ytick',[-1 0 1],'yticklabel',strvcat('-1','','0','','1'));

set(AI,'userData',lh);
AI.TimerPeriod = .1;			% 500 ms update
set(AI,'TimerFcn', @UpdatePlot);
start(AI);
while ~isrunning(AI), end;
trigger(AI);

%% ===== UpdatePlot ============================================================
% update plot using peekdata

function UpdatePlot(AI, event)

lh = get(AI, 'userData');			% line handle
q = get(lh,'userData');
q = [q;event.Data.AbsTime(6)];
sampsAcquired = q(1);
tail = q(2);
doDec = q(3);
q(1:3)=[];
if AI.SamplesAcquired <= sampsAcquired, return; end;
sampsThisUpdate = AI.SamplesAcquired - sampsAcquired;
newSamps = peekdata(AI, sampsThisUpdate);
nSamps = length(newSamps);
if doDec,
	ns = ceil(nSamps/200)*200;
	newSamps = reshape([newSamps;NaN*zeros(ns-nSamps,1)],[200 ns/200]);
	newSampsMax = nanmax(newSamps);
	newSampsMin = nanmin(newSamps);
	newSamps = reshape([newSampsMax;newSampsMin],[ns/100,1]);
end;
sampsAcquired = sampsAcquired + nSamps;
ht = tail + [1 , length(newSamps)];
s = get(lh,'ydata');
if ht(2) > length(s), 
	ht(2) = length(s); 
	newSamps = newSamps(1:diff(ht)+1);
end;
s(ht(1):ht(2)) = newSamps;
set(lh,'ydata',s,'userData',[sampsAcquired;ht(2);doDec;q]);
%set(lh,'userData',[ht(2);q(2:end)]);

%% ===== Finalize ============================================================
% finalize plot display on acquisition completion

function Finalize(AI, event)

lh = get(AI, 'userData');			% line handle
y = daqread(AI.LogFileName);
sampsAcquired = length(y);
x = get(gca,'xlim');
x = linspace(0,x(2),length(y));
set(lh, 'xdata',x, 'ydata', y);
q = get(lh,'userData');
q(1:3) = [];
dq = diff(q);
k = find(dq<0);
dq(k)=[];
set(gca,'userData',q);
figure; stem(diff(q));

