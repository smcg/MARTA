function r = marta(action, varargin)
%MARTA  - DAQ-based acquisition tool
%
%	usage:  marta(trials,info, ...)
%
% TRIALS,INFO specify the experiment structure; from PARSEEXPFILE
%
% Recognized 'NAME',VALUE parameters (defaults shown within {}):
%	CONFIG   - saved configuration variable
%	RMS      - RMS level for sound calibration
%	SPL      - SPL level for sound calibration
%	TARGET   - SPL target (dB)
%	RANGE    - SPL range (dB)
%	SRATE    - sampling rate (16000 Hz)
%	NCHAN    - number of sampled channels {2}

% mkt 03/08

%% branch by action
if nargin < 1,
	eval('help marta');
	return;
end;
if isstruct(action), trials = action; action = 'INIT'; end;

switch action,

% ABOUT  - blurb
	case 'ABOUT',
		vers = 'mkt  01/11 v0.2';
		s = {'MARTA  - DAQ-based acquisition tool';
			''
			['  ' vers]};
		helpwin(s, 'About MARTA');

% AUTO  - toggle auto-cycling
	case 'AUTO',
		state = get(gcbf, 'userdata');
		state.AUTO = get(gcbo,'value');
		set(gcbf, 'userdata', state);
		
% CONFIG  - save configuration
	case 'CONFIG',
		if isempty(gcbf),
			set(0,'ShowHiddenHandles', 'on');
			fh = findobj('tag','MARTA1');
			set(0,'ShowHiddenHandles', 'off');
		else,
			fh = gcbf;
		end;
		state = get(fh,'userData');
		layout = struct('MAIN',get(gcbf,'position'));
		layout.BROWSER = [state.BROWSER.A.getX,state.BROWSER.A.getY,state.BROWSER.A.getWidth,state.BROWSER.A.getHeight];
		config = struct('DUR',state.DUR, 'ISI',state.ISI, ...
						'LAYOUT',layout, 'DEFHTML',state.DEFHTML, ...
						'EXPT',state.EXPT, 'HWCFG',[]);
		for k = 1 : length(state.HW),
			if isempty(state.HW{k}), 
				config.HWCFG{k} = [];
			else,
				hw = state.HW{k};
				config.HWCFG{k} = feval(hw.NAME, 'LAYOUT', hw);
			end;
		end;
		if isempty(varargin),
			name = GetName('Save Configuration as...');
			if isempty(name), return; end;
			assignin('base',name,config);
			evalin('base',name);
		else,
			r = config;
		end;

% CLOSE	 - shut down	
	case 'CLOSE',
		if ~strcmp('Exit',questdlg('Exit Marta?','','Exit','Cancel','Exit')), return; end;
		state = get(gcbf, 'userData');
		pause(.5);
		config = marta('CONFIG','GetConfig');
		save([state.EXPNAME '_cfg'],'config');
		fprintf('\nConfiguration saved as %s_cfg.mat\n', state.EXPNAME);
		state.BROWSER.A.hide;
		for k = 1 : length(state.HW),
			if ~isempty(state.HW{k}), 
				hw = state.HW{k};
				feval(hw.NAME, 'CLOSE', hw);
			end;
		end;
		delete(state.TIMER);
		delete(timerfind('Tag','MARTA'));
		set(0,'ShowHiddenHandles', 'on');
		delete(findobj('tag','MARTA'));
		set(0,'ShowHiddenHandles', 'off');
		closereq;
		fprintf('\n  %s terminated %s\n\n', state.EXPNAME, datestr(now));
		diary off;		% stop logging

% LIST  - list update		
	case 'LIST',
		if nargin < 2,
			SetTrial(gcbf,get(gcbo,'value'));
		else,
			SetTrial(gcbf,[],varargin{1});
		end;	

% MIKECAL  - calibrate microphone (noise trial)	
	case 'MIKECAL',
		state = get(gcbf, 'userData');
		if strcmp(state.MODE,'RECORDING'), return; end;
		hw = state.HW{state.CURHW};
		if isrunning(hw.AI),	% turn off plotting
			feval(hw.NAME, 'PLOT', hw); 
			set(state.CONTROLLER.PLOT,'checked','off');
			state.MODE = 'PAUSED';
			set(gcbf, 'userData', state);
		end;
		[cfg,lh,rmsH,splH,targH,rangeH] = InitMikeCal(hw.CFG);
		while 1,
			uiwait(cfg);
			if ~ishandle(cfg), return; end;
			switch get(cfg,'userData'),
				case 0,			% cancel
					delete(cfg);
					return;		
				case 1,			% accept
					hw.CFG.RMS = str2num(get(rmsH,'string'));
					hw.CFG.SPL = str2num(get(splH,'string'));
					hw.CFG.TARGET = str2num(get(targH,'string'));
					hw.CFG.RANGE = str2num(get(rangeH,'string'));
					delete(cfg);
					state.HW{state.CURHW} = hw;
					set(gcbf, 'userData', state);
					fprintf('\nSound Level calibrated:\n%-8s: %g\n%-8s: %g\n%-8s: %g\n%-8s: %g\n\n', ...
							'RMS',hw.CFG.RMS, 'SPL',hw.CFG.SPL, 'TARGET',hw.CFG.TARGET, 'RANGE',hw.CFG.RANGE);
					return;
				case 2,			% record
					s = feval(hw.NAME, 'MIKECAL', hw, state);
                    s = s(:,1);
					wl = round(20*hw.CFG.SRATE/1000);
					set(lh(1),'ydata',s);
					rms = sqrt(filter(rectwin(wl)/wl,1,s.^2));
					set(lh(2),'ydata',rms*2-1);
					rms = median(rms);
					set(rmsH,'string',num2str(rms));
			end;
		end;
		
% PLOT  - toggle plotting		
	case 'PLOT',
		state = get(gcbf, 'userdata');
		if strcmp(state.MODE,'RECORDING'), return; end;
		if strcmp(get(gcbo,'checked'),'on'),
			newState = 'PAUSED';
			set(gcbo, 'checked', 'off');
		else,
			newState = 'PLOTTING';
			set(gcbo, 'checked', 'on');
		end;
		state.MODE = newState;
		set(gcbf, 'userdata', state);
		hw = state.HW{state.CURHW};
		feval(hw.NAME, 'PLOT', hw);

% SATCHK  - toggle saturation check		
	case 'SATCHK',
		state = get(gcbf, 'userdata');
		if strcmp(get(gcbo,'checked'),'on'),
			state.SATCHK = 0;
			set(gcbo, 'checked', 'off');
		else,
			state.SATCHK = 1;
			set(gcbo, 'checked', 'on');
		end;
		set(gcbf, 'userdata', state);

% RECORD  - initiate/truncate recording
	case 'RECORD',
		completed = 0;
		if nargin > 1,
			set(0,'ShowHiddenHandles', 'on');
			fh = findobj('tag','MARTA1');
			set(0,'ShowHiddenHandles', 'off');
			if nargin > 2,
				completed = varargin{2};	% nonzero if all samples acquired (normal completion)
			end;
		else,
			fh = gcbf;
		end;
		state = get(fh, 'userdata');
		if ~isempty(state.CURHW),	% if HW handler
			hw = state.HW{state.CURHW};
			if isrunning(hw.AI), 
				if state.AUTO,		% disable autocycling
					set(state.CONTROLLER.AUTO,'value',0);
					state.AUTO = 0;
					set(fh, 'userData', state);
				end;
				stop(hw.AI);		% truncated; will re-enter via StopFcn
				t = timerfind('Tag','MARTA');
				for k = 1 : length(t), stop(t(k)); end;
				delete(t);
                if isempty(state.CURIDX), 
                    stims = []; 
                else,
                    stims = state.EXPT.TRIALS(state.CURIDX).STIM;
                end;
				for si = 1 : length(stims),
					if ~isempty(stims(si).EXTRA) && ~isempty(stims(si).EXTRA.HANDLER),
						feval(stims(si).EXTRA.HANDLER,'ABORT');		% signal stimulus handler (active or not!)
					end;
				end;
				return;
			end;
			set(hw.AI,'TimerFcn',[]);
			clip = get(hw.AI,'userData');
			if iscell(clip) || isempty(clip), clip = 0; end;
			if state.SATCHK && clip,
				set(state.CONTROLLER.AUTO,'value',0);
				state.AUTO = 0;
				set(fh, 'userData', state);
			end;
			if completed,
                if isempty(state.CURIDX),
                    stims = [];
                else,
                    stims = state.EXPT.TRIALS(state.CURIDX).STIM;
                end;
				for si = 1 : length(stims),
					s = stims(si);
					if isfield(s,'EXTRA') && ~isempty(s.EXTRA) && ~isempty(s.EXTRA.HANDLER),
						feval(s.EXTRA.HANDLER,'COMPLETED');		% signal stimulus handler (active or not!)
					end;
				end;
			end;
		end;
		
% stop active recording
		if strcmp(state.MODE,'RECORDING'),
			if state.TIMER.Running, stop(state.TIMER); end;
			t = timerfind('Tag','MARTA');
			for k = 1 : length(t),
				while strcmp(t(k).Running,'on'), end;
			end;
			delete(t);
			html = '<HTML><HEAD><TITLE>STIMULUS DISPLAY</TITLE></HEAD><BODY bgcolor="black" /></HTML>';
			state.BROWSER.B.setHtmlText(html);	% clear to black
			set(state.CONTROLLER.PROGRESS,'visible','off');
			set(state.CONTROLLER.PLOT,'enable','on');
			set(state.CONTROLLER.LIST,'enable','on');
			set(state.CONTROLLER.RECORD,'checked','off');
			set(state.CONTROLLER.CTLB,'string','Start','backgroundColor',[.8 .9 .8]);
			state.MODE = 'PAUSED';
			set(fh, 'userData', state);			
			figure(fh);
			
% init ISI countdown			
			if state.AUTO,
				isi = str2num(get(state.CONTROLLER.ISI,'string'));
				if ~isempty(isi), state.ISI = isi; end;
				if isi == 0,
					set(fh, 'userData', state);
					SetTrial(fh, [], 1);
					marta('RECORD','ISI');
					return;
				else,
					state.MODE = 'ISI';
					set(fh, 'userData', state);
					set(state.TIMER,'StartDelay',state.ISI,'TimerFcn',{@ISITimeOut,fh});
					start(state.TIMER);
					return;
				end;
			else,			% step trial
				SetTrial(fh, [], 1);
			end;
			
% abort ISI countdown
		elseif strcmp(state.MODE,'ISI'),
			stop(state.TIMER);
			set(state.CONTROLLER.PLOT,'enable','on');
			set(state.CONTROLLER.LIST,'enable','on');
			set(state.CONTROLLER.RECORD,'checked','off');
			set(state.CONTROLLER.AUTO,'value',0);
			state.AUTO = 0;
			state.MODE = 'PAUSED';
			set(fh, 'userData', state);
			return;

% initiate logged recording
		else,
			trial = state.CURTRIAL;
			nStim = length(trial.STIM);
			if strcmp(trial.TYPE,'RECORD') && isempty(trial.FNAME),
				state.FNAME = GetName('Acquire additional trial as...');	% get "extra" trial filename interactively
				if isempty(state.FNAME), return; end;
			end;
			set(state.CONTROLLER.PLOT,'checked','off','enable','off');
			set(state.CONTROLLER.LIST,'enable','off');
			set(state.CONTROLLER.RECORD,'checked','on');
			set(state.CONTROLLER.CTLB,'string','Abort','backgroundColor',[.9 .8 .8]);
			state.MODE = 'RECORDING'; 
			dur = str2num(get(state.CONTROLLER.DUR,'string'));
			if ~isempty(dur), state.DUR = dur; end;
			set(fh, 'userData', state);

% handle pause (N.B. only first stimulus displayed on PAUSE trials, DELAY ignored, HANDLER ignored)
			if strcmpi(trial.TYPE,'PAUSE'),
				UpdateStimDisp(trial.STIM.HTML, state.EXPT.INFO.CSS, state.BROWSER, fh);
				set(state.CONTROLLER.AUTO,'value',0);
				state.AUTO = 0;
				set(fh, 'userData', state);

% handle one stimulus/no timeout case
			elseif nStim==1 && (isempty(trial.STIM.DELAY) || trial.STIM.DELAY==0),
				if trial.STIM.RECORD && strcmpi(trial.TYPE,'RECORD') && ~isempty(state.CURHW),
					feval(hw.NAME, 'RECORD', hw, state);
					while ~isrunning(hw.AI), end;			% wait for DAQ object to begin
				else,
					stop(state.TIMER);
					set(state.TIMER,'StartDelay',state.DUR,'TimerFcn','marta(''RECORD'',''DUMMY'')');
					start(state.TIMER);
				end;	
				UpdateStimDisp(trial.STIM.HTML, state.EXPT.INFO.CSS, state.BROWSER, fh);
				if ~isempty(trial.STIM.EXTRA) && ~isempty(trial.STIM.EXTRA.HANDLER),
					extra = trial.STIM.EXTRA;
					feval(extra.HANDLER,extra.CONTENT);	% call stimulus handler
				end;
			
% general case:  init stimulus delay timeouts
			else,
				stims = state.EXPT.TRIALS(state.CURIDX).STIM;
				for si = 1 : length(stims),
					delay = stims(si).DELAY;
					if isempty(delay), delay = 0; end;
					t = timer('StartDelay',delay/1000,'Tag','MARTA', 'busyMode','queue', ...
							'TimerFcn',{@StimTimeOut,stims(si),fh});
					start(t);
				end;
			end;	% general case
		end;	% init recording
		
% DEFAULT  - assume action holds name of expFile		
	otherwise,
		Initialize(trials, varargin{:})

end;

%% ===== GetName ============================================================
% get name for additional trial acquisition

function name = GetName(ps)

pos = get(0,'monitorPositions');
pos = pos(1,:);
width = 300;
height = 100;
figPos = [pos(1)+(pos(3)-width)/2, pos(2)+(pos(4)-height)/2, width, height];

cfg = dialog('name', ps, ...
	'menubar', 'none', ...
	'Position', figPos, ...
	'UserData', 0);

% name field
eh = uicontrol(cfg, ...
	'Position', [20 60 width-40 20], ...
	'Style', 'edit', ...
	'HorizontalAlignment', 'left', ...
	'String', '');

% OK, cancel buttons
uicontrol(cfg, ...		% buttons
	'Position',[width/2-70 15 60 25], ...
	'String','OK', ...
	'Callback','set(gcbf,''UserData'',1);uiresume');
uicontrol(cfg, ...
	'Position',[width/2+10 15 60 25], ...
	'String','Cancel', ...
	'Callback','set(gcbf,''UserData'',0);uiresume');

% wait for input
uiwait(cfg);
if ishandle(cfg) && get(cfg, 'UserData'),
	name = strtok(get(eh, 'string'));
else,
	name = [];
end;
if ishandle(cfg), delete(cfg); end;

%% ===== Initialize ============================================================
% perform initialization sequence

function Initialize(trials, varargin)

set(0,'ShowHiddenHandles', 'on');
fh = findobj('tag','MARTA1');
set(0,'ShowHiddenHandles', 'off');
if ~isempty(fh), figure(fh); return; end;

%% defaults
defHTML = 'text://<HTML><CENTER style="font-family:Arial;font-size:64;font-weight:bold;color:#000088"><P/><I>Don''t w<FONT color="#C80000">o</FONT>rry, be h<FONT color="#00C800">a</FONT>ppy...</I></CENTER></HTML>';

defHWcfg = struct('HW', 'acq_audio', ...		% default acquisition handler
					'ADAPTOR', 'winsound', ...	% default acquisition hw
					'NCHAN', 2, ...				% number of channels
					'RMS', [], ...				% RMS -> SPL mapping
					'SPL', [], ...
					'TARGET', [], ...			% range checking
					'RANGE', [], ...
					'SRATE', 16000);			% sampling rate (Hz)
				
defCfg = struct('DUR', 3, ...					% duration (secs)
				'ISI', 0, ...					% ISI (secs)
				'LAYOUT', [], ...				% window positions
				'DEFHTML', defHTML, ...			% default HTML display
				'EXPT', [], ...					% experiment info
				'HWCFG', []);					% default HW configuration
defCfg.HWCFG = {defHWcfg};

%% parse args
cfg = []; rms = []; spl = []; target = []; rng = []; sRate = []; nChan = [];
info = varargin{1};
for ai = 3 : 2 : length(varargin),
	switch upper(varargin{ai-1}),
		case 'CONFIG', cfg = varargin{ai};
		case 'RMS', rms = varargin{ai};
		case 'SPL', spl = varargin{ai};
		case 'TARGET', target = varargin{ai};
		case 'RANGE', rng = varargin{ai};
		case 'SRATE', sRate = varargin{ai};
		case 'NCHAN', nChan = varargin{ai};
		otherwise, error('unrecognized parameter (%s)',varargin{ai-1});
	end;
end;
if ~isempty(cfg),
	fn = fieldnames(cfg);
	for k = 1 : length(fn),
		defCfg.(fn{k}) = cfg.(fn{k});
	end;
end;
cfg = defCfg; clear defCfg;
if ~isempty(rms),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.RMS = rms;
	end;
end;
if ~isempty(spl),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.SPL = spl;
	end;
end;
if ~isempty(target),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.TARGET = target;
	end;
end;
if ~isempty(rng),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.RANGE = rng;
	end;
end;
if ~isempty(sRate),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.SRATE = sRate;
	end;
end;
if ~isempty(nChan),
	for k = 1 : length(cfg.HWCFG),
		cfg.HWCFG{k}.NCHAN = nChan;
	end;
end;

%% parse the experiment file
% [p,f,e] = fileparts(expFile);
% if isempty(e), e = '.xml'; expFile = fullfile(p,[f,e]); end;
% logFile = fullfile(p,[f,'.log']);
% expName = f;

if isempty(cfg.EXPT),
	expt = struct('TRIALS',trials, 'INFO',info);
else,
	if isempty(trials), trials = cfg.EXPT.TRIALS; end;
	info = cfg.EXPT.INFO;
	expt = cfg.EXPT;
end;
logFile = info.EXTRA.LOGNAME;
[p,expName] = fileparts(logFile);

diary(logFile);		% start logging
ls = char(ones(1,60)*61);
fprintf('\n\n%s\n  %s initiated %s\n%s\n\n', ls, expName, datestr(now),ls);
% if isempty(cfg.EXPT),
% 	if ~exist(expFile,'file'),
% 		error('experiment file %s not found', expFile);
% 	end;
% 	[trials,info] = ParseExpFile(expFile);
% 	expt = struct('TRIALS',trials, 'INFO',info);
% else,
% 	trials = cfg.EXPT.TRIALS;
% 	info = cfg.EXPT.INFO;
% 	expt = cfg.EXPT;
% end;
trialList = {trials.FNAME};
kk = setdiff([1:length(trials)],strmatch('RECORD',upper({trials.TYPE})));
for k = kk,
	trialList{k} = sprintf('%s_%04d', upper(trials(k).TYPE), k);
end;
trialList{end+1} = '<< Select Interactively >>';

%% init browser
[s,b] = web(cfg.DEFHTML, '-notoolbar');
m = get(get(b,'rootPane'),'menuBar');
m.hide;						% hide the menubar
a = get(b,'TopLevelAncestor');
layout = cfg.LAYOUT;
if isempty(cfg.LAYOUT),
	layout = [0 0 800 475];
else,
	layout = cfg.LAYOUT.BROWSER;
end;
a.setLocation(layout(1),layout(2));
a.setSize(layout(3),layout(4));
set(a,'title','Stimulus Display');
a.show;
browser = struct('B',b, 'A',a);	

%% init controller
color = [0.9255 0.9137 0.8471];
if isempty(cfg.LAYOUT),
	width = 400;
	height = 300;
	pos = get(0,'monitorPositions');
	pos = pos(1,:);
%	pos = [pos(1)+(pos(3)-width)-5, 36, width, height];
	pos = [pos(1)+(pos(3)-width)-5, 57, width, height];
else,
	pos = cfg.LAYOUT.MAIN;
end;
fh = figure('name','MARTA', ...
			'tag','MARTA1', ...
			'numberTitle', 'off', ...
			'menubar', 'none', ...
			'position', pos, ...
			'closeRequestFcn', 'marta CLOSE', ...
			'color', color, ...
			'resize', 'off');

% menu items
mh = uimenu(fh, 'label', '&File');
uimenu(mh, 'label', 'About MARTA...', ...
			'callback', 'marta ABOUT');
uimenu(mh, 'label', '&Save Configuration', ...
			'separator', 'on', ...
			'callback', 'marta CONFIG');
uimenu(mh, 'label', 'E&xit', ...
			'separator', 'on', ...
			'accelerator', 'X', ...
			'callback', 'close');

mh = uimenu(fh, 'label', '&Control');
pmH = uimenu(mh, 'label', 'Toggle &Plotting', ...
			'accelerator', 'P', ...
			'callback', 'marta PLOT');
uimenu(mh, 'label', 'Saturation Check', ...
			'checked', 'on', ...
			'callback', 'marta SATCHK');
mcH = uimenu(mh, 'label', 'Mike Calibration', ...
			'callback', 'marta MIKECAL');
uimenu(mh, 'label', '&Backup', ...
			'separator', 'on', ...
			'accelerator', 'B', ...
			'callback', 'marta(''LIST'',-1)');
uimenu(mh, 'label', '&Next Trial', ...
			'accelerator', 'N', ...
			'callback', 'marta(''LIST'',1)');
rmH = uimenu(mh, 'label', '&Record Trial', ...
			'separator', 'on', ...
			'accelerator', 'R', ...
			'callback', 'marta RECORD');

% border
uipanel(fh, ...
			'position', [.03 .35 .94 .65], ...
			'borderType', 'etchedOut', ...
			'fontName', 'Helvetica', ...
			'fontSize', 10, ...
			'backgroundColor', color, ...
			'title', ' Current Trial ');


% trial list
listH = uicontrol(fh, ...
			'style','listbox', ...
			'units','normalized', ...
			'position',[0.0475 0.62 0.905 0.33], ...
			'fontName', 'Helvetica', ...
			'fontSize', 10, ...
			'string', trialList, ...	
			'value', 1, ...
			'backgroundColor', 'w', ...
			'hitTest', 'off', ...
			'callback', 'marta LIST');

% prompt
promptH = uicontrol(fh, ...
			'style','edit', ...
			'units','normalized', ...
			'position',[0.047 0.46 0.905 0.15], ...
			'fontName', 'Helvetica', ...
			'fontSize', 24, ...
			'horizontalAlignment', 'left', ...
			'enable', 'inactive', ...
			'backgroundColor', [1 1 .9], ...
			'hitTest', 'off', ...
			'string', trials(1).PROMPT);
			
% progress bar
uicontrol(fh, ...
			'style','text', ...
			'units','normalized', ...
			'position',[0.04 0.365 0.15 0.07], ...
			'fontName', 'Helvetica', ...
			'fontSize', 10, ...
			'horizontalAlignment', 'right', ...
			'backgroundColor', color, ...
			'hitTest', 'off', ...
			'string', 'Progress:');
pH = axes('position', [0.2 0.37 0.75 0.07]);
set(pH, 'color','w', 'box','on', 'xtick',[], 'ytick',[], 'xlim',[0 1],'ylim',[0 1]);
progressH = patch([0 0 1 1],[0 1 1 0],'r','edgeColor','w','visible','off');

% acquisition duration
uicontrol(fh, ...
			'style','text', ...
			'units','normalized', ...
			'position',[0.04 0.22 0.5 0.08], ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'horizontalAlignment', 'right', ...
			'backgroundColor', color, ...
			'string', 'Acquisition Duration (secs):');
durH = uicontrol(fh, ...
			'style','edit', ...
			'units','normalized', ...
			'position',[0.55 0.22 0.15 0.1], ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'horizontalAlignment', 'center', ...
			'backgroundColor', 'w', ...
			'string', sprintf('%.2g',cfg.DUR));

% ISI
uicontrol(fh, ...
			'style','text', ...
			'units','normalized', ...
			'position',[0.74 0.22 0.05 0.08], ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'horizontalAlignment', 'right', ...
			'backgroundColor', color, ...
			'string', 'ISI:');
isiH = uicontrol(fh, ...
			'style','edit', ...
			'units','normalized', ...
			'position',[0.8 0.22 0.15 0.1], ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'horizontalAlignment', 'center', ...
			'backgroundColor', 'w', ...
			'string', sprintf('%.2g',cfg.ISI));

% autocycling checkbox
autoH = uicontrol(fh, ...
			'style','checkbox', ...
			'units','normalized', ...
			'position',[0.12 0.08 0.3 0.1], ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'string', 'Auto Cycling', ...
			'value', 0, ...
			'interruptible', 'off', ...
			'callback', 'marta AUTO');

% control button
ctlH = uicontrol(fh, ...
			'style','pushbutton', ...
			'units','normalized', ...
			'position',[0.5 0.05 0.4 0.14], ...
			'fontName', 'Helvetica', ...
			'fontSize', 18, ...
			'fontWeight', 'bold', ...
			'backgroundColor', [.8 .9 .8], ...
			'string', 'Start', ...
			'interruptible', 'off', ...
			'callback', 'marta RECORD');

% controller
controller = struct('CTL', fh, ...				% controller figure handle
					'PLOT', pmH, ...			% plot menu handle
					'RECORD', rmH, ...			% record menu handle
					'LIST', listH, ...			% trial listbox
					'PROMPT', promptH, ...		% prompt field
					'PROGRESS', progressH, ...	% progress bar
					'DUR', durH, ...			% duration field
					'ISI', isiH, ...			% ISI field
					'AUTO', autoH, ...			% auto cycling checkbox handle
					'CTLB', ctlH);				% control button

%% init handlers
hwList = {trials.HW};
hwList = unique(hwList(find(~cellfun('isempty',hwList))));
if isempty(hwList), hw = []; end;
for k = 1 : length(hwList),		
	try,
		hw{k} = feval(hwList{k},'INIT',cfg.HWCFG{k},fh);
	catch,
		lasterr
		fprintf('warning:  initialization failed for %s\n', hwList{k});
		hw{k} = [];
	end;
end;
if isempty(hw), set(mcH, 'enable','off'); end;

%% finalize

% internal state
state = struct( ...
				'MODE', 'PAUSED', ...			% status
				'AUTO', 0, ...					% auto cycling
				'EXT', '.daq', ...				% logged file extension
				'DUR', cfg.DUR, ...				% active duration (secs)
				'ISI', cfg.ISI, ...				% active ISI (secs)
				'SATCHK', 1, ...				% saturation check
				'DEFHTML', cfg.DEFHTML, ...		% default HTML
				'BROWSER', browser, ...			% browser info
				'CONTROLLER', controller, ...	% controller window
				'EXPT', expt, ...				% experiment info
				'HW', [], ...					% hardware handler states
				'CURHW', [], ...				% current handler
				'CURIDX', [], ...				% current trial index
				'CURTRIAL', [], ...				% current trial
				'FNAME', [], ...				% trial filename
				'EXPNAME', expName, ...			% experiment filename
				'TIMER', timer);				% DUMMY/ISI timer

state.HW = hw;
if ~isempty(hw{1}), state.CURHW = 1; end;	% initial handler, if available

set(fh, 'handleVisibility','callback', 'userData',state);
SetTrial(fh, 1);
config = marta('CONFIG','GetConfig');
save([expName '_cfg'],'config');
fprintf('Configuration saved as %s_cfg.mat\n\n', expName);
%uicontrol(ctlH);
figure(fh);


%% ===== InitMikeCal ============================================================
% initialize microphone calibration dialog

function [fh,lh,rmsH,splH,targH,rangeH] = InitMikeCal(cfg)

figPos = get(0, 'ScreenSize');
width = 500;
height = 400;
figPos = [figPos(1)+(figPos(3)-width)/2, figPos(2)+(figPos(4)-height)/2, width, height];

fh = figure('name', ['Sound Level Calibration'], ...
	'menubar', 'none', ...
	'Position', figPos);

ah = axes('position',[.13 .5 .8 .4]);
sr = cfg.SRATE;
lh(1) = line(linspace(0,1000,sr)',zeros(sr,1),'color','b');
lh(2) = line(linspace(0,1000,sr)',zeros(sr,1),'color','r');
set(ah,'xlim',[0 1000],'ylim',[-1 1],'ytick',[-1 0 1],'box','on');
color = [0.9255 0.9137 0.8471];
title('Sampled Microphone Input');
xlabel('msecs');

set(fh,'windowStyle','modal','color',color,'resize','off','numberTitle','off');

% edit fields
x = 18; y = 9;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 10 2], ...
			'string', 'Map', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'right');
x = x + 12;
rmsH = uicontrol(fh, ...
			'units','characters', ...
			'style', 'edit', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'string', cfg.RMS, ...
			'position',[x y 15 2]);
x = x + 17;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 15 2], ...
			'string', '(RMS) to', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'left');
x = x + 14;
splH = uicontrol(fh, ...
			'units','characters', ...
			'style', 'edit', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'string', cfg.SPL, ...
			'position',[x y 15 2]);
x = x + 16;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 10 2], ...
			'string', '(SPL)', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'left');	

x = 18; y = 5.5;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 10 2], ...
			'string', 'Target:', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'right');
x = x + 12;
targH = uicontrol(fh, ...
			'units','characters', ...
			'style', 'edit', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'string', cfg.TARGET, ...
			'position',[x y 15 2]);
x = x + 17;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 12 2], ...
			'string', 'within', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'center');
x = x + 14;
rangeH = uicontrol(fh, ...
			'units','characters', ...
			'style', 'edit', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'string', cfg.RANGE, ...
			'position',[x y 15 2]);
x = x + 16;
uicontrol(fh, ...
			'style', 'text', ...
			'units','characters', ...
			'position',[x y 10 2], ...
			'string', 'db', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'backgroundColor', color, ...
			'horizontalAlignment', 'left');	

% buttons
uicontrol(fh, ...
			'Position',[width/2-170 18 100 30], ...
			'String','Record', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'fontWeight', 'bold', ...
			'Callback','set(gcbf,''UserData'',2);uiresume');
uicontrol(fh, ...
			'Position',[width/2+20 18 80 30], ...
			'String','Accept', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'fontWeight', 'bold', ...
			'Callback','set(gcbf,''UserData'',1);uiresume');
uicontrol(fh, ...
			'Position',[width/2+120 18 80 30], ...
			'String','Cancel', ...
			'fontName', 'Helvetica', ...
			'fontSize', 12, ...
			'fontWeight', 'bold', ...
			'Callback','set(gcbf,''UserData'',0);uiresume');


%% ===== ISITimeOut ============================================================
% update current trial

function ISITimeOut(t, evt, fh)

state = get(fh,'userData');
state.MODE = 'PAUSED';
set(fh, 'userData', state);
SetTrial(fh, [], 1);
marta('RECORD','ISI');


%% ===== SetTrial ============================================================
% update current trial

function SetTrial(fh, newTrial, increment)

state = get(fh, 'userData');

if nargin > 2,
	newTrial = get(state.CONTROLLER.LIST,'value') + increment;
	if newTrial < 1, return; end;
	if newTrial > length(state.EXPT.TRIALS)+1, 
		newTrial = length(state.EXPT.TRIALS)+1; 
	end;
end;
dur = str2num(get(state.CONTROLLER.DUR,'string'));
if ~isempty(dur), state.DUR = dur; end;
isi = str2num(get(state.CONTROLLER.ISI,'string'));
if ~isempty(isi), state.ISI = isi; end;
state.CURTRIAL = newTrial;
set(state.CONTROLLER.LIST,'value',newTrial);
if newTrial > length(state.EXPT.TRIALS),
	set(state.CONTROLLER.AUTO,'value',0);
	state.AUTO = 0;
	trial = state.EXPT.TRIALS(end);
	trial.FNAME = '';
	trial.TYPE = 'RECORD';
	trial.PROMPT = '';
	trial.STIM = trial.STIM(1);
	trial.STIM.DELAY = 0;
	trial.STIM.RECORD = 1;
	trial.STIM.EXTRA = [];
	trial.STIM.HTML = '<HTML><HEAD><TITLE>STIMULUS DISPLAY</TITLE></HEAD><BODY bgcolor="white" /></HTML>';
	newTrial = [];
else,
	trial = state.EXPT.TRIALS(newTrial);
end;
state.CURTRIAL = trial;
state.CURIDX = newTrial;
state.FNAME = trial.FNAME;
	
% update current handler
if ~isempty(trial.HW),
	for k = 1 : length(state.HW),
		if isempty(state.HW{k}),
			state.CURHW = [];
		elseif strcmp(trial.HW,state.HW{k}.NAME), 
			state.CURHW = k;
			break;
		end;
	end;
end;
	
% update prompt
set(state.CONTROLLER.PROMPT,'string',trial.PROMPT);
	
% update duration, ISI
if ~isempty(trial.DUR),
	set(state.CONTROLLER.DUR,'string',sprintf('%.2g',trial.DUR));
	state.DUR = trial.DUR;
end;
if ~isempty(trial.ISI),
	set(state.CONTROLLER.ISI,'string',sprintf('%.2g',trial.ISI));
	state.ISI = trial.ISI;
end;
	
% set record enabling based on valid FNAME
if isempty(state.FNAME),
	set(state.CONTROLLER.RECORD,'enable','off');
else,
	set(state.CONTROLLER.RECORD,'enable','on');
end;
set(fh, 'userData', state);


%% ===== StimTimeOut ============================================================
% process stimulus after its onset delay (relative to start of trial)

function StimTimeOut(t, evt, stim, fh)

state = get(fh,'userData');
if stim.RECORD,
	if isempty(state.CURHW),		% no hw handler
		stop(state.TIMER);
		set(state.TIMER,'StartDelay',state.DUR,'TimerFcn','marta(''RECORD'',''DUMMY'')');
		start(state.TIMER);
	else,							% init recording
		hw = state.HW{state.CURHW};
		feval(hw.NAME, 'RECORD', hw, state);
		while ~isrunning(hw.AI), end;			% wait for DAQ object to start
	end;	
end;
UpdateStimDisp(stim.HTML, state.EXPT.INFO.CSS, state.BROWSER, fh);
for k = 1 : length(stim.EXTRA),
	if isempty(stim.EXTRA(k).HANDLER), continue; end;
	feval(stim.EXTRA(k).HANDLER,stim.EXTRA(k).CONTENT);	% call stimulus handler
end;


%% ===== UpdateStimDisp ============================================================
% update stimulus display

function UpdateStimDisp(html, css, browser, fh)

if ~isempty(html),
	hdr = html(1:min([4,length(html)]));
	if strcmp(hdr,'http') || strcmp(hdr,'file'),
		browser.B.setCurrentLocation(html);
	elseif strcmp(hdr,'text'),
		browser.B.setHtmlText(html(8:end));
	else,	% add pre/post formatting
		htmlText = '<HTML><HEAD><TITLE>STIMULUS DISPLAY</TITLE>';
		if ~isempty(css),
			htmlText = [htmlText,'<STYLE TYPE="text/css">',css,'</STYLE>'];
		end;
		html = [htmlText,'</HEAD><BODY>',html,'</BODY></HTML>'];
		browser.B.setHtmlText(html);
	end;
end;
browser.A.show;
figure(fh);
