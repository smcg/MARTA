function r = StimTest(action, varargin)
%STIMTEST  - test MARTA stimulus list
%
%	usage:  StimTest(trials,info)
%
% Given the TRIALS and INFO structures output from PARSEEXPFILE this procedure
% emulates the presentation of stimuli under MARTA for testing purposes

% mkt 09/09

%% branch by action
if nargin < 1,
	eval('help StimTest');
	return;
end;

if isstruct(action), 
	trials = action;
	if ~all(isfield(trials,{'TYPE','FNAME','PROMPT','DUR','ISI','STIM','HW'})),
		error('invalid TRIALS structure for %s (see ParseExpFile for expected output)', inputname(1));
	end;
	if nargin < 2, error('missing INFO'); end;
	action = 'INIT'; 
end;

switch action,

% ABOUT  - blurb
	case 'ABOUT',
		vers = 'mkt  09/09 v0.1';
		s = {'STIMTEST  - MARTA stimulus list testing';
			''
			['  ' vers]};
		helpwin(s, 'About StimTest');

% AUTO  - toggle auto-cycling
	case 'AUTO',
		state = get(gcbf, 'userdata');
		state.AUTO = get(gcbo,'value');
		set(gcbf, 'userdata', state);
		
% CLOSE	 - shut down	
	case 'CLOSE',
%		if ~strcmp('Exit',questdlg('Exit StimTest?','','Exit','Cancel','Exit')), return; end;
		state = get(gcbf, 'userData');
		pause(.5);
		state.BROWSER.A.hide;
		delete(state.TIMER);
		delete(timerfind('Tag','STIMTEST'));
		set(0,'ShowHiddenHandles', 'on');
		delete(findobj('tag','STIMTEST'));
		set(0,'ShowHiddenHandles', 'off');
		clear global MODE
		closereq;

% LIST  - list update		
	case 'LIST',
		if nargin < 2,
			SetTrial(gcbf,get(gcbo,'value'));
		else,
			SetTrial(gcbf,[],varargin{1});
		end;	

% RECORD  - initiate/truncate recording
	case 'RECORD',
	
% get state
		if nargin > 1,	% via callback
			set(0,'ShowHiddenHandles', 'on');
			fh = findobj('tag','STIMTEST1');
			set(0,'ShowHiddenHandles', 'off');
		else,			% via button press
			fh = gcbf;
		end;
		state = get(fh, 'userdata');
		global MODE
		
% stop active recording
		if strcmp(MODE,'RECORDING'),
			t = timerfind('Tag','STIMTEST');
			for k = 1 : length(t),
				stop(t);
			end;
			delete(t);
			html = '<HTML><HEAD><TITLE>STIMULUS DISPLAY</TITLE></HEAD><BODY bgcolor="black" /></HTML>';
			state.BROWSER.B.setHtmlText(html);	% clear to black
			set(state.CONTROLLER.PROGRESS,'visible','off');
			set(state.CONTROLLER.PLOT,'enable','on');
			set(state.CONTROLLER.LIST,'enable','on');
			set(state.CONTROLLER.RECORD,'checked','off');
			set(state.CONTROLLER.CTLB,'string','Start','backgroundColor',[.8 .9 .8]);
			MODE = 'PAUSED';
			if nargin == 1,
				set(state.CONTROLLER.AUTO,'value',0);
				state.AUTO = 0;
			end;
			set(fh, 'userData', state);			
			stims = state.CURTRIAL.STIM;
			for si = 1 : length(stims),
				s = stims(si);
				if isfield(s,'EXTRA') && ~isempty(s.EXTRA) && ~isempty(s.EXTRA(end).HANDLER),
					feval(s.EXTRA(end).HANDLER,'COMPLETED');		% signal stimulus handler (active or not!)
				end;
			end;
			figure(fh);
			
% handle autocycling			
			if get(state.CONTROLLER.AUTO,'value'),
				isi = str2num(get(state.CONTROLLER.ISI,'string'));
				if ~isempty(isi), state.ISI = isi; end;

% immediate
				if isi == 0,
					SetTrial(fh, [], 1);
					StimTest('RECORD','ISI');
% ISI
				else,
					MODE = 'ISI';
					if strcmp(state.TIMER.Running,'on'),
						set(state.TIMER,'stopFcn','');
						stop(state.TIMER);
					end;
					set(state.TIMER,'StartDelay',state.ISI, 'busymode','drop', 'timerFcn',@NullTimeOut, 'StopFcn',{@ISITimeOut,fh});
					start(state.TIMER);
				end;

% step trial
			else,			
				SetTrial(fh, [], 1);
			end;

			return;	% end active recording
			
% abort ISI countdown
		elseif strcmp(MODE,'ISI'),
			stop(state.TIMER);
			set(state.CONTROLLER.PLOT,'enable','on');
			set(state.CONTROLLER.LIST,'enable','on');
			set(state.CONTROLLER.RECORD,'checked','off');
			set(state.CONTROLLER.AUTO,'value',0);
			state.AUTO = 0;
			MODE = 'PAUSED';
			return;
		end;
		
% initiate logged recording
		trial = state.CURTRIAL;
		nStim = length(trial.STIM);

% get "extra" trial filename interactively
		if strcmp(trial.TYPE,'RECORD') && isempty(trial.FNAME),
			state.FNAME = GetName('Acquire additional trial as...');	
			if isempty(state.FNAME), return; end;
		end;
		set(state.CONTROLLER.PLOT,'checked','off','enable','off');
		set(state.CONTROLLER.LIST,'enable','off');
		set(state.CONTROLLER.RECORD,'checked','on');
		set(state.CONTROLLER.CTLB,'string','Abort','backgroundColor',[.9 .8 .8]);
		MODE = 'RECORDING'; 
		dur = str2num(get(state.CONTROLLER.DUR,'string'));
		if ~isempty(dur), state.DUR = dur; end;
		set(fh, 'userData', state);

% handle pause (N.B. only first stimulus displayed on PAUSE trials, DELAY ignored, HANDLER ignored)
		if strcmpi(trial.TYPE,'PAUSE'),
			UpdateStimDisp(trial.STIM.HTML, state.EXPT.INFO.CSS, state.BROWSER, fh);
			set(state.CONTROLLER.AUTO,'value',0);
			state.AUTO = 0;
			set(fh, 'userData', state);
			figure(fh);

% handle one stimulus/no timeout case
		elseif nStim==1 && (isempty(trial.STIM.DELAY) || trial.STIM.DELAY==0),
			if strcmp(state.TIMER.Running,'on'),
				set(state.TIMER,'stopFcn','');
				stop(state.TIMER);
			end;
			set(state.TIMER,'StartDelay',state.DUR, 'busymode','drop', 'timerFcn',@NullTimeOut, ...
					'stopFcn','StimTest(''RECORD'',''DUMMY'')');
			start(state.TIMER);
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
				t = timer('StartDelay',delay/1000,'Tag','STIMTEST', 'busyMode','drop', ...
						'TimerFcn',{@StimTimeOut,stims(si),fh});
				start(t);
			end;
		end;	% general case

		
% DEFAULT  - assume action holds trials for initialization		
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

function Initialize(trials, info)

expt = struct('TRIALS',trials, 'INFO',info);

set(0,'ShowHiddenHandles', 'on');
fh = findobj('tag','STIMTEST1');
set(0,'ShowHiddenHandles', 'off');
if ~isempty(fh), figure(fh); return; end;

%% defaults
defHTML = 'text://<HTML><CENTER style="font-family:Arial;font-size:64;font-weight:bold;color:#000088"><P/><I>Don''t w<FONT color="#C80000">o</FONT>rry, be h<FONT color="#00C800">a</FONT>ppy...</I></CENTER></HTML>';

trialList = {trials.FNAME};
kk = setdiff([1:length(trials)],strmatch('RECORD',upper({trials.TYPE})));
for k = kk,
	trialList{k} = sprintf('%s_%04d', upper(trials(k).TYPE), k);
end;
trialList{end+1} = '<< Select Interactively >>';

%% init browser
[s,b] = web(defHTML, '-notoolbar');
m = get(get(b,'rootPane'),'menuBar');
m.hide;						% hide the menubar
a = get(b,'TopLevelAncestor');
layout = [0 0 800 475];
a.setLocation(layout(1),layout(2));
a.setSize(layout(3),layout(4));
set(a,'title','Stimulus Display');
a.show;
browser = struct('B',b, 'A',a);	

%% init controller
color = [0.9255 0.9137 0.8471];
width = 400;
height = 300;
pos = get(0,'monitorPositions');
pos = pos(1,:);
pos = [pos(1)+(pos(3)-width)-5, 57, width, height];
fh = figure('name','StimTest', ...
			'tag','STIMTEST1', ...
			'numberTitle', 'off', ...
			'menubar', 'none', ...
			'position', pos, ...
			'closeRequestFcn', 'StimTest CLOSE', ...
			'color', color, ...
			'resize', 'off');

% menu items
mh = uimenu(fh, 'label', '&File');
uimenu(mh, 'label', 'About StimTest...', ...
			'callback', 'StimTest ABOUT');
uimenu(mh, 'label', '&Save Configuration', ...
			'enable','off', ...
			'separator', 'on', ...
			'callback', 'marta CONFIG');
uimenu(mh, 'label', 'E&xit', ...
			'separator', 'on', ...
			'accelerator', 'X', ...
			'callback', 'close');

mh = uimenu(fh, 'label', '&Control');
pmH = uimenu(mh, 'label', 'Toggle &Plotting', ...
			'enable','off', ...
			'accelerator', 'P', ...
			'callback', 'marta PLOT');
uimenu(mh, 'label', 'Saturation Check', ...
			'enable','off', ...
			'checked', 'off', ...
			'callback', 'marta SATCHK');
mcH = uimenu(mh, 'label', 'Mike Calibration', ...
			'enable','off', ...
			'callback', 'marta MIKECAL');
uimenu(mh, 'label', '&Zero Ref', ...
			'enable','off', ...
			'accelerator', 'Z', ...
			'callback', 'marta ZEROREF');
uimenu(mh, 'label', '&Backup', ...
			'separator', 'on', ...
			'accelerator', 'B', ...
			'callback', 'StimTest(''LIST'',-1)');
uimenu(mh, 'label', '&Next Trial', ...
			'accelerator', 'N', ...
			'callback', 'StimTest(''LIST'',1)');
rmH = uimenu(mh, 'label', '&Record Trial', ...
			'enable','off', ...
			'separator', 'on', ...
			'accelerator', 'R', ...
			'callback', 'StimTest RECORD');

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
			'callback', 'StimTest LIST');

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
			'string', sprintf('%.2g',3));

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
			'string', sprintf('%.2g',0));

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
			'callback', 'StimTest AUTO');

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
			'callback', 'StimTest RECORD');

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

%% finalize

% internal state
state = struct( ...
				'AUTO', 0, ...					% auto cycling
				'EXT', '.daq', ...				% logged file extension
				'DUR', 3, ...					% active duration (secs)
				'ISI', 0, ...					% active ISI (secs)
				'SATCHK', 0, ...				% saturation check
				'DEFHTML', defHTML, ...			% default HTML
				'BROWSER', browser, ...			% browser info
				'CONTROLLER', controller, ...	% controller window
				'EXPT', expt, ...				% experiment info
				'HW', [], ...					% hardware handler states
				'CURHW', [], ...				% current handler
				'CURIDX', [], ...				% current trial index
				'CURTRIAL', [], ...				% current trial
				'FNAME', [], ...				% trial filename
				'EXPNAME', [], ...			% experiment filename
				'TIMER', timer);				% DUMMY/ISI timer

global MODE
MODE = 'PAUSED';

set(fh, 'handleVisibility','callback', 'userData',state);
SetTrial(fh, 1);
figure(fh);

if ismac, [s,r] = unix('osascript -e ''tell application "MATLAB" to activate'''); end;


%% ===== ISITimeOut ============================================================
% update current trial

function ISITimeOut(t, evt, fh)

global MODE
MODE = 'PAUSED';
SetTrial(fh, [], 1);
StimTest('RECORD','ISI');


%% ===== NullTimeOut ============================================================
% timeout stub (pseudo recording)

function NullTimeOut(obj, event)

% disp TIMEOUT
% disp(datestr(event.Data.time))


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

% stop(state.TIMER);
% set(state.TIMER,'StartDelay',state.DUR,'TimerFcn','StimTest(''RECORD'',''DUMMY'')');
set(state.TIMER,'stopFcn','');
stop(state.TIMER);
set(state.TIMER,'StartDelay',state.DUR, 'busymode','drop', 'timerFcn',@NullTimeOut, ...
		'stopFcn','StimTest(''RECORD'',''DUMMY'')');
start(state.TIMER);

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
		htmlText = '<HTML><HEAD>';
		htmlText = [htmlText '<TITLE>STIMULUS DISPLAY</TITLE>'];
		htmlText = [htmlText '<META http-equiv="content-type" content="text-html; charset=utf-8">'];
 		if ~isempty(css),
 			htmlText = [htmlText,'<STYLE TYPE="text/css">',css,'</STYLE>'];
 		end;

% this code converts unicode entities (##x -> &#x)
 		kk = findstr(html,'##x');
 		if ~isempty(kk),
 			for k = 1 : length(kk), html(kk(k)) = '&'; end;
 		end;

% this code handles Argyro's {B}word{B} emboldening sequences
		kk = findstr(html,'{B}');
		if ~isempty(kk),
			if mod(length(kk),2), error('{B} pairs must be matched'); end;
			for k = length(kk) : -2 : 1,
				html = [html(1:kk(k-1)-1) , '<b>' , html(kk(k-1)+3:kk(k)-1) , '</b>' , html(kk(k)+3:end)];
			end;
		end;

		html = [htmlText,'</HEAD><BODY>',html,'</BODY></HTML>'];
		browser.B.setHtmlText(html);
	end;
end;
browser.A.show;
figure(fh);
