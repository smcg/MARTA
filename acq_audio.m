function hw = acq_audio(action, varargin)
%ACQ_AUDIO  - MARTA DAQ-based audio handler

%% branch by action
switch action,

% CLOSE
	case 'CLOSE',
		hw = varargin{1};
		stop(hw.AI);
		delete(hw.AI);
		jh = getjframe(hw.LW);
		jh.setAlwaysOnTop(false);
		delete(hw.LW);
		delete(hw.PW);

% INIT
	case 'INIT',
		hw = HWInit(varargin{1},varargin{2});
		
% LAYOUT  - update stored window positions
	case 'LAYOUT',
		hw = varargin{1};
		cfg = hw.CFG;
		cfg.PWPOS = get(hw.PW,'position');
		cfg.LWPOS = get(hw.LW,'position');
		hw = cfg;
		
% MIKECAL  - microphone calibration (noise recording)
	case 'MIKECAL',
		hw = DoMikeCal(varargin{1}, varargin{2});
	
% PLOT  - toggle plotting
	case 'PLOT',
		TogglePlotting(varargin{1});
		
% RECORD  - init recording
	case 'RECORD',
		InitRecording(varargin{1}, varargin{2});
		
% error
	otherwise,
		error('unrecognized action (%s) in ACQ_AUDIO', action);
end;


%% ===== HWInit ============================================================
% create analog input object, add properties

function hw = HWInit(cfg, fh)

%% create DAQ object
info = daqhwinfo(cfg.ADAPTOR);
AI = eval(info.ObjectConstructorName{1});
idx = [1 : cfg.NCHAN];
addchannel(AI, idx);
if cfg.NCHAN > 1,
	fprintf('N.B. recording %d channels, but only channel 1 is plotted\n', length(idx));
end;
cfg.SRATE = setverify(AI,'sampleRate',cfg.SRATE);
%bot = 36;
bot = 57;

%% create waveform/RMS plotting window
if isfield(cfg,'PWPOS'),
	pos = cfg.PWPOS;
else,
	width = 700;
	height = 200;
	pos = [5 bot, width, height];
end;
cfg.PWPOS = pos;
pwH = figure('name','ACQ_AUDIO', ...
			'tag','MARTA', ...
			'position', pos, ...
			'color', 'w', ...
			'menubar','none', ...
			'numberTitle','off', ...
			'doubleBuffer','on', ...
			'keyPressFcn','figure(get(gcbf,''userdata''))', ...
			'userData', fh, ...
			'closeRequestFcn', '');
paH = axes('position',[.08 .11 .78 .83]);		% waveform
set(paH, 'xtick',[],'ytick',[], 'box','on');
raH = axes('position',[.87 .11 .06 .83]);		% rms level
ph = patch([0 0 1 1],[0 0 0 0],'g');
set(raH, 'xlim',[0 1],'xtick',[],'yaxislocation','right', 'box','on', 'ylim',[0 110],'userData',ph);
		
%% create subject level window
if isfield(cfg,'LWPOS'),
	pos = cfg.LWPOS;
else,
	width = 300;
	height = 50;
	pos = [715 bot, width, height];
end;
cfg.LWPOS = pos;
lwH = figure('name','LEVEL', ...
			'tag','MARTA', ...
			'position', pos, ...
			'color', 'w', ...
			'menubar','none', ...
			'numberTitle','off', ...
			'doubleBuffer','on', ...
			'keyPressFcn','figure(get(gcbf,''userdata''))', ...
			'userData', fh, ...
			'closeRequestFcn', '');
jh = getjframe(lwH);
jh.setAlwaysOnTop(true);
xx = [.04:.0925:1];
c = 'bbbbgggrrr';
for k = 1 : 10,
	x = [xx(k) xx(k+1)-.01];
	lbH(k) = patch([x(1) x(1) x(2) x(2)],[.05 .05 .05 .05],c(k),'edgecolor',c(k));
end;
set(gca,'xlim',[0 1],'ylim',[0 1],'xtick',[],'ytick',[],'box','on');
%set([pwH lwH],'handleVisibility','callback');

%% return configuration
hw = struct('NAME', mfilename, ...		% handler name
			'CFG', cfg, ...				% configuration (may have changed)
			'AI', AI, ...				% DAQ object
			'PW', pwH, ...				% plotting window
			'PA', paH, ...				% plotting axis
			'RA', raH, ...				% rms level axis
			'LW', lwH, ...				% level window
			'LB', lbH);					% level bars

%% ===== Decimate ============================================================
% returns interleaved min/max of decimated sample windows

function ds = Decimate(s)

ns0 = length(s);
deciRate = floor(ns0/400)*10;	% about 100 samples per update
dr2 = deciRate*2;
ns = ceil(ns0/dr2)*dr2;
s = reshape([s;NaN*zeros(ns-ns0,1)],[dr2 ns/dr2]);
sMax = nanmax(s);
sMin = nanmin(s);
ds = reshape([sMax;sMin],[ns/deciRate,1]);

%% ===== DoMikeCal ============================================================
% process microphone calibration trial

function s = DoMikeCal(hw, state)

% config DAQ object
AI = hw.AI;
AI.BufferingMode = 'auto';
AI.TriggerType = 'immediate';
AI.TriggerRepeat = 0;
AI.LogFileName = '';
AI.LoggingMode = 'Memory';
set(AI,'StopFcn', []);
nSamps = round(1 * hw.CFG.SRATE);	% one second
AI.SamplesPerTrigger = nSamps;
start(AI);
while isrunning(AI), end;
s = getdata(AI,nSamps);

%% ===== InitRecording ============================================================
% initiate logged recording

function InitRecording(hw, state)

% if FNAME exists, inc retention count
while exist([state.FNAME,state.EXT],'file'),
	k = findstr('_',state.FNAME);
	if isempty(k),
		n = 1;
		state.FNAME = [state.FNAME,'_'];
		k = length(state.FNAME);
	else,
		n = str2num(state.FNAME(k(end)+1:end)) + 1;
	end;
	state.FNAME = sprintf('%s%02d',state.FNAME(1:k(end)),n);
end;

% config DAQ object
AI = hw.AI;
AI.BufferingMode = 'auto';
AI.TriggerType = 'manual';
AI.TriggerRepeat = 0;
AI.LogFileName = [state.FNAME,state.EXT];
AI.LoggingMode = 'Disk';
%AI.LoggingMode = 'Disk&Memory';
nSamps = round(state.DUR * hw.CFG.SRATE);
AI.SamplesPerTrigger = nSamps;
set(AI,'StopFcn',@Finalize);

% init plotting
axes(hw.PA);
cla;
x = linspace(0,state.DUR,nSamps/100);
y = zeros(1,nSamps/100);
plot(x,y,'color','g','linestyle',':');
lh = line(x,NaN*y, 'eraseMode','none', 'hittest','off', 'clipping','off');
set(lh, 'userData', [0 0]);		% sampsAcquired, last tail
set(hw.PA,'xlim',[0 state.DUR],'ylim',[-1 1],'drawmode','fast','ytick',[-1 0 1],'yticklabel',strvcat('-1','','0','','1'));
AI.TimerPeriod = .1;			% 100 ms update
%set(hw.LB, 'ydata', [.05 .05 .05 .05], 'userData',0);	% clear level bars
set(hw.LB, 'userData',0);		% clear level bars
w = round(20*hw.CFG.SRATE/1000);
w = rectwin(w)/w;
rmsMap = [hw.CFG.RMS hw.CFG.SPL hw.CFG.TARGET hw.CFG.RANGE];
if length(rmsMap) < 4, rmsMap = []; end;
% {line handle, patch handle, progress bar, sampsToAcquire, level bars, saturation level, window, rmsMap}
set(AI,'userData', {lh, get(hw.RA,'userData') state.CONTROLLER.PROGRESS, nSamps, hw.LB, w, rmsMap});
set(AI, 'TimerFcn', @UpdatePlot);			% start timer

% trigger
start(AI);
while ~isrunning(AI), end;
trigger(AI);

%% ===== TogglePlotting ============================================================
% toggle (non-logged) plotting state

function TogglePlotting(hw)

% stop & clear if already running
if isrunning(hw.AI),
	stop(hw.AI);
	set(hw.AI,'TimerFcn',[]);
	return;
end;

% configure AI for manual triggering
tp = .1;				% timer period (100 ms)
set(hw.AI, 'samplesPerTrigger', tp * hw.CFG.SRATE);
set(hw.AI, 'triggerRepeat', 1);					% manually triger twice
set(hw.AI, 'triggerType','manual');
set(hw.AI, 'timerPeriod', tp);
set(hw.AI, 'loggingMode', 'Memory');
set(hw.AI, 'StopFcn', []);

% start acquisition
start(hw.AI);
while ~isrunning(hw.AI), end;
trigger(hw.AI);

% plot first buffer of samples
s = getdata(hw.AI);								% blocks until available
axes(hw.PA);
cla;
lh = plot(s);
figure(get(gcf,'userdata'));
set(hw.PA, 'xlim',[1 length(s)],'ylim',[-1 1],'xtick',[],'drawmode','fast','ytick',[-1 0 1],'yticklabel',strvcat('-1','','0','','1'));
w = round(20*hw.CFG.SRATE/1000);
w = rectwin(w)/w;
rmsMap = [hw.CFG.RMS hw.CFG.SPL hw.CFG.TARGET hw.CFG.RANGE];
if length(rmsMap) < 4, rmsMap = []; end;
set(hw.AI, 'userData',{lh get(hw.RA,'userData') w rmsMap});		% store line handle, patch handle, window, rms mapping
set(hw.AI, 'TimerFcn', @UpdatePlot);			% start timer

%% ===== UpdatePlot ============================================================
% update plot using peekdata

function UpdatePlot(AI, event)

lh = get(AI, 'userData');			% line handle

% logging in progress
if length(lh) > 4,		% recording in progress
	ph = lh{2}; progressH = lh{3}; nSamps = lh{4}; lbh = lh{5}; w = lh{6}; rmsMap = lh{7}; lh = lh{1};
	q = get(lh,'userData');
	sampsAcquired = q(1); 
	tail = q(2);
	if AI.SamplesAcquired <= sampsAcquired, return; end;
	sampsThisUpdate = AI.SamplesAcquired - sampsAcquired;
	newSamps0 = peekdata(AI, sampsThisUpdate);
	newSamps0 = newSamps0(:,1);		% FOR NOW:  1st channel only

% construct interleaved min/max of decimated sample windows
	ns0 = length(newSamps0);
 	sampsAcquired = sampsAcquired + ns0;
	newSamps = Decimate(newSamps0);
	ht = tail + [1 , length(newSamps)];
	s = get(lh,'ydata');
	if ht(2) > length(s), 
		ht(2) = length(s); 
		newSamps = newSamps(1:diff(ht)+1);
	end;
	s(ht(1):ht(2)) = newSamps;
	set(lh,'ydata',s,'userData',[sampsAcquired ht(2)]);

% update progress bar	
	set(progressH,'xdata',[0 0 1 1]*sampsAcquired/nSamps,'visible','on');
	
% update SPL levels
	if ~isempty(rmsMap),
		rms = sqrt(filter(w,1,newSamps0.^2));
		dB = rmsMap(2) + 20.*log10(max(rms) / rmsMap(1));
		set(ph, 'ydata', [0 1 1 0]*dB);			% update experimenter level
		level = round((dB-rmsMap(3))/110*330/(2*rmsMap(4)+1)) + 6;	% assumes 0:110 dB scale
		if level < 1, level = 1; elseif level > 10, level = 10; end;
		if level > get(lbh(1),'userData'),
			set(lbh(1), 'userData',level);
		end;
	end;

% non-logged plotting in progress
else,
	s = peekdata(AI, AI.SamplesPerTrigger);
	ph = lh{2}; w = lh{3}; rmsMap = lh{4}; lh = lh{1};
	if ~ishandle(lh), return; end;
	set(lh,'ydata',s);
	if ~isempty(rmsMap),
		rms = sqrt(filter(w,1,s.^2));
		dB = rmsMap(2) + 20.*log10(max(rms) / rmsMap(1));
		set(ph, 'ydata', [0 1 1 0]*dB);
	end;
end;
drawnow;

%% ===== Finalize ============================================================
% finalize plot display on acquisition completion

function Finalize(AI, event)

lh = get(AI, 'userData');			% line handle
progressH = lh{3}; nSamps = lh{4}; lbh = lh{5}; w = lh{6}; lh = lh{1};
y = daqread(AI.LogFileName);
y = y(:,1);			% FOR NOW:  1st channel only
sampsAcquired = length(y);
x = get(get(lh,'parent'),'xlim');
x = linspace(0,x(2),length(y));
set(lh, 'xdata',x, 'ydata',y, 'eraseMode','normal');
nSat = sum(abs(y)>=1);
clipped = 0;
if nSat,
	ss = sprintf('; %d samples (%.0f%%) clipped',nSat,100*nSat/nSamps);
	rms = sqrt(filter(w,1,y.^2));
	k = find(abs(y)>=1);
	if sum(rms(k) > .5), clipped = 1; ss = [ss,'; SATURATED']; end;		% saturation is RMS exceeding .5 at clipped samples
else,
	ss = '';
end;
set(AI, 'userData', clipped);
level = get(lbh(1),'userData');		% update subject level bars
for k = 1 : 10,
	if k <= level,
		y = [.05 .95 .95 .05];
	else,
		y = [.05 .05 .05 .05];
	end;
	set(lbh(k), 'ydata', y);
end;
if sampsAcquired == nSamps, 
	fprintf('%s\t(normal completion%s)\n', AI.LogFileName, ss);
else, 
	fprintf('%s\t(TRUNCATED; %d of %d samples acquired%s)\n', AI.LogFileName, sampsAcquired, nSamps, ss);
end;
set(progressH,'xdata',[0 0 1 1]*sampsAcquired/nSamps,'visible','on');
marta('RECORD','FINALIZE',(sampsAcquired==nSamps));
