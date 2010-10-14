function PlayNoisebox(varargin)
%PLAYNOISEBOX  - controls the noisebox either independently or through
%stimulus parameters
%
% Value 'SMLNML' [speech: arm MSB LSB noise: arm MSB LSB]

persistent nbSTATE;
try
	nbSTATE.init;
	if nbSTATE.init == true && isempty(findobj('Tag','PlayNoiseboxFig')),
		nbSTATE.init = false;
		PlayNoisebox('INIT');
	end
catch
    nbSTATE.init = false;
    PlayNoisebox('INIT');
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
        nbSTATE.HW        = [];
        nbSTATE.fig       = [];

        % initialize figure;
        %%
        nbSTATE.fig = findobj('Tag','PlayNoiseboxFig');
        if isempty(nbSTATE.fig)
            nbSTATE.fig = figure('position',[0 0 116 295],'menubar','none','numbertitle','off','name','PlayNoisebox','Tag','PlayNoiseboxFig');
        end
        centerfig(nbSTATE.fig);
        %%
        base = 0.35;
        nbSTATE.nsarmui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.15 0.8 0.08],'style','checkbox','string','Noise','fontsize',14,...
            'Callback','PlayNoisebox(''CB'');');
        uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.08 0.4 0.07],'style','text','string','MSB','fontsize',12);
        uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base+0.08 0.4 0.07],'style','text','string','LSB','fontsize',12);
        nbSTATE.noiseMSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.25 0.08],'style','text','string','F','fontsize',14);
        nbSTATE.noiseLSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base 0.25 0.08],'style','text','string','F','fontsize',14);
        nbSTATE.noiseMSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.35 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
            'Callback','PlayNoisebox(''CB'');','sliderstep',[1/16 1/16]);
        nbSTATE.noiseLSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.75 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
            'Callback','PlayNoisebox(''CB'');','sliderstep',[1/16 1/16]);
        base = 0.75;
        nbSTATE.sparmui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.15 0.8 0.08],'style','checkbox','string','Speech','fontsize',14,...
            'Callback','PlayNoisebox(''CB'');');
        uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base+0.08 0.4 0.07],'style','text','string','MSB','fontsize',12,...
            'Callback',@PlayNoisebox);
        uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base+0.08 0.4 0.07],'style','text','string','LSB','fontsize',12);
        nbSTATE.speechMSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.25 0.08],'style','text','string','F','fontsize',14);
        nbSTATE.speechLSBtxtui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.5 base 0.25 0.08],'style','text','string','F','fontsize',14);
        nbSTATE.speechMSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.35 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
            'Callback','PlayNoisebox(''CB'');','sliderstep',[1/16 1/16]);
        nbSTATE.speechLSBui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.75 base 0.15 0.08],'style','slider','max',15,'min',0,'value',15,...
            'Callback','PlayNoisebox(''CB'');','sliderstep',[1/16 1/16]);
        base = 0.1;
        nbSTATE.overrideui = uicontrol('Parent',nbSTATE.fig,'units','normalized','position',[0.1 base 0.8 0.08],'style','checkbox','string','Override','fontsize',14,...
            'Callback','PlayNoisebox(''CB'');');
        umh = uimenu(nbSTATE.fig,'Label','Noisebox');

        %% Initialize hardware
        nbSTATE.HW = digitalio('nidaq','Dev1');
        addline(nbSTATE.HW,0:1,0,'out');
        addline(nbSTATE.HW,0:7,1,'out');
        addline(nbSTATE.HW,0:7,2,'out');
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
            PlayNoisebox('SEND');
        end
    case 'SEND'
        putvalue(nbSTATE.HW,[nbSTATE.speechArm nbSTATE.noiseArm dec2binvec(hex2dec(nbSTATE.speech.LSB),4) dec2binvec(hex2dec(nbSTATE.speech.MSB),4) dec2binvec(hex2dec(nbSTATE.noise.LSB),4) dec2binvec(hex2dec(nbSTATE.noise.MSB),4)])
    case 'SAVE'
    case 'LOAD'
	case 'ABORT',
		PlayNoisebox('0FF0FF');
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

            PlayNoisebox('SEND');
        end
end
