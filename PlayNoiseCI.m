function PlayNoiseCI(varargin)
%PlayNoiseCI  - controls the noisebox either independently or through
%stimulus parameters
%
% Value 'SMLNML' [speech: arm MSB LSB noise: arm MSB LSB]

persistent nbSTATE;
try
	nbSTATE.init;
	if nbSTATE.init == true && isempty(findobj('Tag','PlayNoiseCIFig')),
		nbSTATE.init = false;
		PlayNoiseCI('INIT');
	end
catch
	nbSTATE.init = false;
	PlayNoiseCI('INIT');
	nbSTATE.init = true;
end

if nargin<1,
	return;
end

switch (varargin{1})
	case 'INIT',
		nbSTATE.speechArm = false;
		nbSTATE.noiseArm  = false;
		nbSTATE.override  = false;
		nbSTATE.noise     = struct('LSB','F','MSB','F');
		nbSTATE.speech    = struct('LSB','F','MSB','F');
		nbSTATE.HW1        = [];
		nbSTATE.HW2        = [];
		nbSTATE.fig       = [];
		foo  = load('mtbabble');
		foo2 = load('ramp');
		%         nbSTATE.data      = [zeros(size(foo.mtbabble)),foo.mtbabble];
		%         nbSTATE.data      = [foo.mtbabble , zeros(size(foo.mtbabble))];
		foo.mtbabble(1:numel(foo2.ramp)) = foo.mtbabble(1:numel(foo2.ramp)).*foo2.ramp(:);
		nbSTATE.data      = repmat(foo.mtbabble(:),1,2);
		%         nbSTATE.data      = foo.mtbabble;

		% initialize figure;
		%%
		nbSTATE.fig = findobj('Tag','PlayNoiseCIFig');
		if isempty(nbSTATE.fig)
			nbSTATE.fig = figure('position',[0 0 116 295],'menubar','none','numbertitle','off','name','PlayNoiseCI','Tag','PlayNoiseCIFig');
		end
		centerfig(nbSTATE.fig);
		%%
		base = 0.35;
		nbSTATE.nsarmui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.15 0.8 0.08],'style','checkbox','string','Noise','fontsize',14,...
			'Callback','PlayNoiseCI(''CB'');');
		uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.08 0.4 0.07],'style','text','string','MSB','fontsize',12);
		uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base+0.08 0.4 0.07],'style','text','string','LSB','fontsize',12);
		nbSTATE.noiseMSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.25 0.08],'style','text','string','F','fontsize',14);
		nbSTATE.noiseLSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base 0.25 0.08],'style','text','string','F','fontsize',14);
		nbSTATE.noiseMSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.35 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
			'Callback','PlayNoiseCI(''CB'');','sliderstep',[1/16 1/16]);
		nbSTATE.noiseLSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.75 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
			'Callback','PlayNoiseCI(''CB'');','sliderstep',[1/16 1/16]);
		base = 0.75;
		nbSTATE.sparmui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.15 0.8 0.08],'style','checkbox','string','Speech','fontsize',14,...
			'Callback','PlayNoiseCI(''CB'');');
		uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.08 0.4 0.07],'style','text','string','MSB','fontsize',12,...
			'Callback',@PlayNoiseCI);
		uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base+0.08 0.4 0.07],'style','text','string','LSB','fontsize',12);
		nbSTATE.speechMSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.25 0.08],'style','text','string','F','fontsize',14);
		nbSTATE.speechLSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base 0.25 0.08],'style','text','string','F','fontsize',14);
		nbSTATE.speechMSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.35 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
			'Callback','PlayNoiseCI(''CB'');','sliderstep',[1/16 1/16]);
		nbSTATE.speechLSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.75 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
			'Callback','PlayNoiseCI(''CB'');','sliderstep',[1/16 1/16]);
		base = 0.1;
		nbSTATE.overrideui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.8 0.08],'style','checkbox','string','Override','fontsize',14,...
			'Callback','PlayNoiseCI(''CB'');');
		umh = uimenu(nbSTATE.fig,'Label','Noisebox');

		%% Initialize hardware
		daqinfo = daqhwinfo('winsound');
		for i0=1:numel(daqinfo.BoardNames),
			try
				obj = analogoutput('winsound',i0-1); %% 2 corresponds to analog output 1/2 when default is 3/4
				s=struct(obj);
				% Find the device name:
				hw = gethwinfo(s.uddobject);
				devname = hw.DeviceName;
				delete(obj);
				if strcmp(devname,'M-Audio Delta 44 1/2'),
					boardid = i0-1;
				end
			catch
			end
		end
		nbSTATE.HW1 = analogoutput('winsound',boardid);
		nbSTATE.sampleRate = 48000;
		addchannel(nbSTATE.HW1, 1:2);

		nbSTATE.HW2 = digitalio('nidaq','Dev1');
		addline(nbSTATE.HW2,0:1,0,'out');
		addline(nbSTATE.HW2,0:7,1,'out');
		addline(nbSTATE.HW2,0:7,2,'out');

		try
			setverify(nbSTATE.HW1, 'SampleRate', nbSTATE.sampleRate);
		catch
			error(['Unable to set SampleRate to ' num2str(sampleRate) '. Using default value.'])
		end
		%% Deal wiyh callback
	case 'CB',
		set(nbSTATE.speechMSBtxtui,'string',dec2hex(round(get(nbSTATE.speechMSBui,'value'))));
		set(nbSTATE.speechLSBtxtui,'string',dec2hex(round(get(nbSTATE.speechLSBui,'value'))));
		set(nbSTATE.noiseMSBtxtui,'string',dec2hex(round(get(nbSTATE.noiseMSBui,'value'))));
		set(nbSTATE.noiseLSBtxtui,'string',dec2hex(round(get(nbSTATE.noiseLSBui,'value'))));
		nbSTATE.speechArm = get(nbSTATE.sparmui,'value');
		nbSTATE.noiseArm  = get(nbSTATE.nsarmui,'value');
		nbSTATE.override  = get(nbSTATE.overrideui,'value');
		nbSTATE.noise     = struct('LSB',get(nbSTATE.noiseLSBtxtui,'string'),'MSB',get(nbSTATE.noiseMSBtxtui,'string'));
		nbSTATE.speech    = struct('LSB',get(nbSTATE.speechLSBtxtui,'string'),'MSB',get(nbSTATE.speechMSBtxtui,'string'));
		%         nbSTATE.noise

		if nbSTATE.override,
			PlayNoiseCI('SEND');
		end
	case 'SEND'
		putvalue(nbSTATE.HW2,[nbSTATE.speechArm false dec2binvec(hex2dec(nbSTATE.speech.LSB),4) dec2binvec(hex2dec(nbSTATE.speech.MSB),4) dec2binvec(hex2dec('F'),4) dec2binvec(hex2dec('F'),4)])
		if nbSTATE.noiseArm == 1,
			PlayNoiseCI('PLAY');
		else
			PlayNoiseCI('STOP');
		end
	case 'PLAY'
		if isrunning(nbSTATE.HW1),
			stop(nbSTATE.HW1);
		end
		putdata(nbSTATE.HW1, nbSTATE.data/10^((100/255*hex2dec([nbSTATE.noise.MSB,nbSTATE.noise.LSB]))/20));
		start(nbSTATE.HW1);
	case 'STOP'
		stop(nbSTATE.HW1);
	case 'SAVE'
	case 'LOAD'
	case 'ABORT',
		PlayNoiseCI('1000FF');
	case 'COMPLETED',
		PlayNoiseCI('ABORT');
	otherwise,
		value = varargin{1};
		if ~nbSTATE.override,
			nbSTATE.speechArm = str2num(value(1));
			nbSTATE.noiseArm  = str2num(value(4));
			nbSTATE.noise     = struct('LSB',value(6),'MSB',value(5));
			nbSTATE.speech    = struct('LSB',value(3),'MSB',value(2));

			set(nbSTATE.sparmui,'value',nbSTATE.speechArm);
			set(nbSTATE.nsarmui,'value',nbSTATE.noiseArm);
			set(nbSTATE.overrideui,'value',nbSTATE.override);
			set(nbSTATE.speechMSBui,'value',hex2dec(nbSTATE.speech.MSB));
			set(nbSTATE.speechLSBui,'value',hex2dec(nbSTATE.speech.LSB));
			set(nbSTATE.noiseMSBui,'value',hex2dec(nbSTATE.noise.MSB));
			set(nbSTATE.noiseLSBui,'value',hex2dec(nbSTATE.noise.LSB));
			set(nbSTATE.speechMSBtxtui,'string',dec2hex(round(get(nbSTATE.speechMSBui,'value'))));
			set(nbSTATE.speechLSBtxtui,'string',dec2hex(round(get(nbSTATE.speechLSBui,'value'))));
			set(nbSTATE.noiseMSBtxtui,'string',dec2hex(round(get(nbSTATE.noiseMSBui,'value'))));
			set(nbSTATE.noiseLSBtxtui,'string',dec2hex(round(get(nbSTATE.noiseLSBui,'value'))));

			PlayNoiseCI('SEND');
		end
end
