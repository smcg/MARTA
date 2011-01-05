function [finaltrialarray,info] = ParseExpFile(expFileName,debug)
%PARSEEXPFILE  - parse experiment file
%
%	usage:  [trials,info] = ParseExpFile(expFileName,debug)
%
% Given experiment file EXPFILENAME in XML format returns expanded TRIALS list
% and experiment INFO structure

% Satrajit Ghosh 2/26/08

% expFileName = 'test.xml';

%% Initialize parameters
if nargin<2 || isempty(debug),
    debug = 0;
end
extrastruct   = struct('HANDLER','','CONTENT','');
stimstruct    = struct('DELAY',[],'RECORD',1,'HTML','','EXTRA',extrastruct);
emptytrial    = struct('TYPE','','FNAME','','PROMPT','','DUR',[],'ISI',[],'STIM',stimstruct,'HW','','id',0);
emptyblock    = struct('name','foo','cond','','flag','','hw','','nreps',1,'rand','none','dur',[],'isi',[],'nargs',0,'args',struct('val',''),'id',0,'def',struct(),'pause','');
emptytemplate = struct('tid',0,'type','','dur',[],'isi',[],'hw','','nargs',0,'stimuli',[]);
emptytoken    = struct('content','','prompt','','mnemonic','','type','record','tid',0,'nreps',1,'dur',[],'isi',[],'arg',struct('val',''),'rep',0,'id',0);
emptypart     = struct('nreps',1,'rand','none');
emptyinfo     = struct('CSS','','EXTRA','');

% Read XML-compatible BSL file
if ~exist(expFileName,'file'),
    error('Missing input file: %s',expFileName);
end
tree       = xml_read(expFileName); 

%% Some checks
% Initialize REDEFBLOCK field to empty if it doesn't exist
if ~isfield(tree.DEFS,'REDEFBLOCK'),
    tree.DEFS.REDEFBLOCK = struct([]);
end

if debug
    CTAwarning = @warning;
    CTAprintf  = @fprintf;
    % prehtml = sprintf('text://<HTML><HEAD><style type="text/css">@import "%s";</style></HEAD><BODY>',tree.INFO.CSS);
    % prehtml = sprintf('text://<HTML><HEAD><link rel="stylesheet" href="%s"></HEAD><BODY>',tree.INFO.CSS);
    prehtml = sprintf('text://<HTML><HEAD><TITLE></TITLE><style>%s</style></HEAD><BODY>',tree.INFO.CSS);
    posthtml= sprintf('</BODY></HTML>');
else
    dummyfunc = @(x,varargin)eval('1;');
    CTAwarning = dummyfunc;
    CTAprintf  = dummyfunc;
    prehtml   = '';
    posthtml  = '';
end
CTAinfo.prehtml  = prehtml;
CTAinfo.posthtml = posthtml;
CTAinfo.warning  = CTAwarning;
CTAinfo.printf   = CTAprintf;

try info = tree.INFO; catch error('missing INFO'); end

% check if CSS is a file

%% Create block definitions
BLOCK = emptyblock(ones(numel(tree.DEFS.DEFBLOCK)+numel(tree.DEFS.REDEFBLOCK),1));
for b0=1:numel(tree.DEFS.DEFBLOCK),
    CTAprintf('Processing DEFBLOCK: %d\n',b0);
    try BLOCK(b0).name      = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.name; catch error('Missing name'); end
    try BLOCK(b0).cond      = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.cond; catch error('Missing cond'); end
    try BLOCK(b0).flag      = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.flag; catch error('Missing flag'); end
    try BLOCK(b0).hw        = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.hw; catch CTAwarning('Missing hw'); end
    try BLOCK(b0).nreps     = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.nreps; catch CTAwarning('Missing nreps'); end
    try BLOCK(b0).rand      = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.rand; catch CTAwarning('Missing rand'); end
    try BLOCK(b0).dur       = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.dur; catch CTAwarning('Missing dur'); end
    try BLOCK(b0).isi       = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.isi; catch CTAwarning('Missing isi'); end
    try BLOCK(b0).nargs     = tree.DEFS.DEFBLOCK(b0).ATTRIBUTE.nargs; catch CTAwarning('Missing nargs'); end
    try BLOCK(b0).pause     = tree.DEFS.DEFBLOCK(b0).PAUSE; catch CTAwarning('Missing pause'); end

    try
    ids = [];
    for a0=1:BLOCK(b0).nargs,
         id = tree.DEFS.DEFBLOCK(b0).ARG(a0).ATTRIBUTE.id;
         ids = [ids,id];
         try 
%              eval(sprintf('BLOCK(%d).args(%d).val = tree.DEFS.DEFBLOCK(%d).ATTRIBUTE.arg%d;',b0,a0,b0,a0));
            if isfield(tree.DEFS.DEFBLOCK(b0).ARG(a0),'CONTENT') && ~isempty(tree.DEFS.DEFBLOCK(b0).ARG(a0).CONTENT),
                BLOCK(b0).args(id).val = tree.DEFS.DEFBLOCK(b0).ARG(a0).CONTENT;
            else
                BLOCK(b0).args(id).val = tree.DEFS.DEFBLOCK(b0).ARG(a0).CDATA_SECTION;
            end                
         catch ME, error('Missing arg id:%d content',id); 
         end
    end
    if BLOCK(b0).nargs ~= numel(unique(ids)),
        error('Mismatch between nargs and number of ARG elements')
    end
    catch ME, error('ARG: Missing attribute id'); end
    BLOCK(b0).id    = 0;
    BLOCK(b0).def       = tree.DEFS.DEFBLOCK(b0);
end

% create redefined blocks
blocklen = numel(tree.DEFS.DEFBLOCK);
for rd0=1:numel(tree.DEFS.REDEFBLOCK),
    idx = blocklen+rd0;
    oldblock = strmatch(tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.oldname,{BLOCK(:).name},'exact');
    if isempty(oldblock),
        error('REDEF: Undefined block %s\n',tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.oldname);
    end        
    BLOCK(idx) = BLOCK(oldblock);
    try BLOCK(idx).name      = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.newname; catch error('Missing newname'); end
    try BLOCK(idx).cond      = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.cond; catch CTAwarning('Missing cond'); end
    try BLOCK(idx).flag      = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.flag; catch CTAwarning('Missing flag'); end
    try BLOCK(idx).hw        = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.hw; catch CTAwarning('Missing hw'); end
    try BLOCK(idx).nreps     = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.nreps; catch CTAwarning('Missing nreps'); end
    try BLOCK(idx).rand      = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.rand; catch CTAwarning('Missing rand'); end
    try BLOCK(idx).dur       = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.dur; catch CTAwarning('Missing dur'); end
    try BLOCK(idx).isi       = tree.DEFS.REDEFBLOCK(rd0).ATTRIBUTE.isi; catch CTAwarning('Missing isi'); end
    
    try,
    for a0=1:numel(tree.DEFS.REDEFBLOCK(rd0).ARG),
         try id = tree.DEFS.REDEFBLOCK(rd0).ARG(a0).ATTRIBUTE.id; catch error('ARG: Missing attribute id'); end
         try 
            if isfield(tree.DEFS.REDEFBLOCK(rd0).ARG(a0),'CONTENT') && ~isempty(tree.DEFS.REDEFBLOCK(rd0).ARG(a0).CONTENT),
                BLOCK(idx).args(id).val = tree.DEFS.REDEFBLOCK(rd0).ARG(a0).CONTENT;
            else
                BLOCK(idx).args(id).val = tree.DEFS.REDEFBLOCK(rd0).ARG(a0).CDATA_SECTION;
            end                
%          catch error('Missing arg%d content',a0); 
%          try eval(sprintf('BLOCK(%d).args(%d).val = tree.DEFS.REDEFBLOCK(%d).ATTRIBUTE.arg%d;',idx,a0,rd0,a0));
%          try eval(sprintf('BLOCK(%d).args(%d).val = tree.DEFS.REDEFBLOCK(%d).ARG(%d).CDATA_SECTION;',idx,a0,rd0,a0));
         catch
             CTAwarning('Missing arg%d content',a0);
         end
    end
    catch ME,
        if strcmp(ME.message, 'Reference to non-existent field ''ARG''.'),
            CTAwarning(ME.message)
        else
            rethrow(ME)
        end
    end
end

% replace block arguments
for b0=1:numel(BLOCK),
    for a0=1:numel(BLOCK(b0).args)
        if ~isempty(BLOCK(b0).pause) 
            BLOCK(b0).pause = sub_replaceArg(BLOCK(b0).pause,sprintf('\\$%d',a0),BLOCK(b0).args(a0).val);
        end
        for t0=1:numel(BLOCK(b0).def.TEMPLATE)
            BLOCK(b0).def.TEMPLATE(t0) = sub_replaceArg(BLOCK(b0).def.TEMPLATE(t0),sprintf('\\$%d',a0),BLOCK(b0).args(a0).val);
        end
        for t0=1:numel(BLOCK(b0).def.TOKEN)
            BLOCK(b0).def.TOKEN(t0) = sub_replaceArg(BLOCK(b0).def.TOKEN(t0),sprintf('\\$%d',a0),BLOCK(b0).args(a0).val);
        end
    end
end

%% Expand blocks

for b0=1:numel(BLOCK),
    % Parse templates
    for t0=1:numel(BLOCK(b0).def.TEMPLATE),
        template(t0) = emptytemplate; %#ok<AGROW>
        try template(t0).type   = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.type; catch error('Missing type'); end
        try template(t0).tid    = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.tid; catch error('Missing tid'); end
        try template(t0).dur    = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.dur; catch CTAwarning('Missing dur'); end
        try template(t0).isi    = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.isi; catch CTAwarning('Missing isi'); end
        try template(t0).hw     = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.hw; catch CTAwarning('Missing hw'); end
        try template(t0).nargs  = BLOCK(b0).def.TEMPLATE(t0).ATTRIBUTE.nargs; catch CTAwarning('Missing nargs'); end
        try 
            template(t0).stimuli= BLOCK(b0).def.TEMPLATE(t0).STIMULI;           
%             if ischar(BLOCK(b0).def.TEMPLATE(t0).STIMULI),
%                 template(t0).stimuli.CONTENT   = BLOCK(b0).def.TEMPLATE(t0).STIMULI;
%                 template(t0).stimuli.ATTRIBUTE = struct([]);
%             elseif isstruct(BLOCK(b0).def.TEMPLATE(t0).STIMULI),
%                 template(t0).stimuli = BLOCK(b0).def.TEMPLATE(t0).STIMULI;
%             elseif iscell(BLOCK(b0).def.TEMPLATE(t0).STIMULI)
%                 for s0=1:numel(BLOCK(b0).def.TEMPLATE(t0).STIMULI),
%                     if ischar(BLOCK(b0).def.TEMPLATE(t0).STIMULI{s0}),
%                         template(t0).stimuli(s0).CONTENT   = BLOCK(b0).def.TEMPLATE(t0).STIMULI{s0};
%                         template(t0).stimuli(s0).ATTRIBUTE = struct([]);
%                     elseif isstruct(BLOCK(b0).def.TEMPLATE(t0).STIMULI{s0}),
%                         template(t0).stimuli(s0) = BLOCK(b0).def.TEMPLATE(t0).STIMULI{s0};
%                     end
%                 end
%             end
        catch error('Missing stimuli'); 
        end
    end

    % Parse tokens
    tokenlist = [];
    for t0=1:numel(BLOCK(b0).def.TOKEN),
        token = emptytoken;
        try 
            if isfield(BLOCK(b0).def.TOKEN(t0),'CONTENT') && ~isempty(BLOCK(b0).def.TOKEN(t0).CONTENT),
                token.content = BLOCK(b0).def.TOKEN(t0).CONTENT; 
            else
                token.content = BLOCK(b0).def.TOKEN(t0).CDATA_SECTION; 
            end                
        catch error('Missing content'); end
        try token.prompt  = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.prompt; catch CTAwarning('Missing prompt'); end
        try token.mnemonic= BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.mnemonic; catch CTAwarning('Missing mnemonic'); end
        try token.tid     = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.tid; catch CTAwarning('Missing tid'); end
        try token.nreps   = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.nreps; catch CTAwarning('Missing nreps'); end
        try token.dur     = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.dur; catch CTAwarning('Missing dur'); end
        try token.isi     = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.isi; catch CTAwarning('Missing isi'); end
        try token.type    = BLOCK(b0).def.TOKEN(t0).ATTRIBUTE.type; catch CTAwarning('Missing type'); end
        
        % create trial structure
        trial = emptytrial;
        
        if token.tid == 0 || ~exist('template','var'),

            trial.TYPE  = token.type;
            trial.DUR   = token.dur;
            trial.ISI   = token.isi;
            trial.HW    = BLOCK(b0).hw;
            trial.STIM(1).HTML  = cat(2,prehtml,token.content,posthtml);
            if strcmpi(trial.TYPE,'record'),
                trial.STIM(1).RECORD = 0;
            end
        else
            idx = find([template(:).tid] == token.tid);
            if template(idx).nargs>0,
                for a0=1:template(idx).nargs,
                    try
                        eval(sprintf('token.arg(%d).val = BLOCK(%d).def.TOKEN(%d).ATTRIBUTE.arg%d;',a0,b0,t0,a0));
                    catch
                        error('Block: %s Token: %s Missing argument %d',BLOCK(b0).name,token.content,a0);
                    end
                end
            end
            % apply template
            temp  = template(idx).stimuli;
            for s0=1:numel(temp),
                temp(s0) = sub_replaceArg(temp(s0),sprintf('\\@%d',0),token.content);
                for a0=1:template(idx).nargs
                    temp(s0) = sub_replaceArg(temp(s0),sprintf('\\@%d',a0),token.arg(a0).val);
                end
            end
            token.stimuli = temp;

            trial.TYPE  = template(idx).type;
            trial.DUR   = [token.dur template(idx).dur];
            trial.ISI   = [token.isi template(idx).isi];
            trial.HW    = template(idx).hw;
            for s0=1:numel(token.stimuli)
                try trial.STIM(s0).DELAY = token.stimuli(s0).ATTRIBUTE.delay; catch CTAwarning('missing delay'); end
                try trial.STIM(s0).RECORD = token.stimuli(s0).ATTRIBUTE.record; catch CTAwarning('missing record'); end
                try trial.STIM(s0).HTML  = cat(2,prehtml,token.stimuli(s0).HTML.CDATA_SECTION,posthtml); catch CTAwarning('missing html'); end
                try
%                     for e0=1:numel(token.stimuli(s0).EXTRA),
				e0 = 1; % ONLY 1 extra allowed
                        try trial.STIM(s0).EXTRA(e0).HANDLER = token.stimuli(s0).EXTRA(e0).HANDLER; catch CTAwarning('missing handler'); end
                        try trial.STIM(s0).EXTRA(e0).CONTENT = token.stimuli(s0).EXTRA(e0).CONTENT; catch CTAwarning('missing content'); end
%                     end
                catch
                    CTAwarning('missing extra');
                end
            end
        end
        if strcmpi(trial.TYPE,'record'),
            token.id  = b0*1000+t0;
            if isempty(token.mnemonic)
                trial.FNAME = token.content;
            else
                trial.FNAME = token.mnemonic;
            end
            trial.FNAME = [trial.FNAME,'_',BLOCK(b0).flag,'_',BLOCK(b0).cond];
        end
        if isempty(token.prompt),
            if isempty(token.mnemonic)
                trial.PROMPT= token.content;
            else
                trial.PROMPT= token.mnemonic;
            end
        end
        if ~isempty(trial.DUR),trial.DUR = trial.DUR(1); end
        if ~isempty(trial.ISI),trial.ISI = trial.ISI(1); end
        trial.id    = token.id;

        tokenlist = [tokenlist;trial(ones(token.nreps,1))];
    end
    numtoks = numel(tokenlist);
    idx = repmat((1:numtoks)',1,BLOCK(b0).nreps);
    if ~strcmpi(BLOCK(b0).rand, 'none'),
        idx = feval(BLOCK(b0).rand,idx);
    end
    BLOCK(b0).tokenlist = tokenlist(idx(:));

    % Create pause trial for each block if requested
    if ~isempty(BLOCK(b0).pause),
        trial = emptytrial;
        for i0=1:numel(BLOCK(b0).pause),
            trial(i0,1) = sub_createPauseTrial(emptytrial,BLOCK(b0).pause(i0),CTAinfo);
        end
        BLOCK(b0).pause     = trial;
    end
end

%% Create block-order
blockorder = {};
insertinfo = [];
trialarray = [];
for p0=1:numel(tree.ORDER.SECTION)
    part = emptypart;
    try part.nreps = tree.ORDER.SECTION(p0).ATTRIBUTE.nreps; catch CTAwarning('missing nreps'); end
    try part.rand  = tree.ORDER.SECTION(p0).ATTRIBUTE.rand; catch CTAwarning('missing rand'); end
    
    % Process TRIALS
    if isfield(tree.ORDER.SECTION(p0),'TRIAL') && ~isempty(tree.ORDER.SECTION(p0).TRIAL),
        trials = [];
        for i0=1:numel(tree.ORDER.SECTION(p0).TRIAL),
            trials = cat(1,trials,sub_createTrial(emptytrial,tree.ORDER.SECTION(p0).TRIAL(i0),CTAinfo));
        end
        idx = repmat((1:numel(trials))',1,part.nreps);
        if ~strcmpi(part.rand, 'none'),
            idx = feval(part.rand,idx);
        end
        trialarray = cat(1,trialarray,trials(idx(:)));
    end

    % Process BLOCKS
    if ischar(tree.ORDER.SECTION(p0).BLOCK)
        blockorder = cat(1,blockorder,repmat({tree.ORDER.SECTION(p0).BLOCK},part.nreps,1));
    elseif iscell(tree.ORDER.SECTION(p0).BLOCK),
        numblocks = numel(tree.ORDER.SECTION(p0).BLOCK);
        idx = repmat((1:numblocks)',1,part.nreps);
        if ~strcmpi(part.rand, 'none'),
            idx = feval(part.rand,idx);
        end
        tree.ORDER.SECTION(p0).BLOCK = tree.ORDER.SECTION(p0).BLOCK(:);
        blockorder = cat(1,blockorder,tree.ORDER.SECTION(p0).BLOCK(idx(:)));
    end
    
     if numel(blockorder) > 0
        insertinfo = [insertinfo;numel(trialarray),numel(blockorder)];
     end
end

if ~isempty(insertinfo),
    [uv,i,j] = unique(insertinfo(:,2),'first');
    insertinfo = insertinfo(i,:);
end
blockidx = [];
for b0=1:numel(blockorder),
    blockidx(b0) = strmatch(blockorder(b0),{BLOCK(:).name},'exact'); %#ok<AGROW>
end

if ~isempty(blockidx),
    FINALBLOCKS = BLOCK(blockidx(:));
else
    FINALBLOCKS = [];
end
blocks2execute = unique(blockidx);
for b0=1:numel(blocks2execute),
    idx = find(blocks2execute(b0) == blockidx);
    for i0=1:numel(idx),
        FINALBLOCKS(idx(i0)).id = i0;
    end
end

%% Create trial structure
temptrialarray  = [];
finaltrialarray = [];
trialarrayidx   = 1;
lastidx         = 0; 

% add block id
for b0=1:numel(FINALBLOCKS),
    for t0=1:numel(FINALBLOCKS(b0).tokenlist),
        if strcmpi(FINALBLOCKS(b0).tokenlist(t0).TYPE,'record'),
            FINALBLOCKS(b0).tokenlist(t0).FNAME = cat(2,FINALBLOCKS(b0).tokenlist(t0).FNAME,sprintf('_%02d',FINALBLOCKS(b0).id));
        end
    end
    if ~isempty(FINALBLOCKS(b0).pause),
        tokenlist = cat(1,FINALBLOCKS(b0).pause,FINALBLOCKS(b0).tokenlist);
    end
    if numel(tokenlist)>0,
        if isempty(tokenlist(1).DUR) tokenlist(1).DUR = FINALBLOCKS(b0).dur; end
        if isempty(tokenlist(1).ISI) tokenlist(1).ISI = FINALBLOCKS(b0).isi; end
        if isempty(tokenlist(1).HW)  tokenlist(1).HW  = FINALBLOCKS(b0).hw; end
    end
    temptrialarray = cat(1,temptrialarray,tokenlist);
        
    %% mechansim to insert trials and blocks individually specified in
    %% ORDER/SECTION in the appropriate order
    if insertinfo(trialarrayidx,2) == b0
        trialidx = (lastidx+1):insertinfo(trialarrayidx,1);
        finaltrialarray = cat(1,finaltrialarray,trialarray(trialidx(:)),temptrialarray);
        %
        if ~isempty(trialidx), lastidx = insertinfo(trialarrayidx,1); end
        trialarrayidx  = trialarrayidx + 1;
        temptrialarray = [];
    end
end

if lastidx < numel(trialarray)
    trialidx = (lastidx+1):numel(trialarray);
    finaltrialarray = cat(1,finaltrialarray,trialarray(trialidx(:)),temptrialarray);
end

% add repetition id
uniquetokens = setdiff(unique([finaltrialarray(:).id]),0);
for i0=1:numel(uniquetokens),
    idx = find([finaltrialarray(:).id] == uniquetokens(i0));
    for j0=1:numel(idx),
        finaltrialarray(idx(j0)).FNAME = cat(2,finaltrialarray(idx(j0)).FNAME,sprintf('_%02d',j0));
    end
end

% add other filename information
for i0=1:numel(finaltrialarray),
    if ~isempty(finaltrialarray(i0).FNAME),
        finaltrialarray(i0).FNAME = sprintf('%s_%03d_%s_%04d_01',tree.INFO.STUDYID,tree.INFO.SUBJECTID,finaltrialarray(i0).FNAME,i0);
    end
end

finaltrialarray = rmfield(finaltrialarray,'id');

%% SUBFUNCTIONS
function struct_out = sub_replaceArg(struct_in,string,replace)
if ischar(struct_in),
    struct_out = regexprep(struct_in,string,replace);
elseif isstruct(struct_in) && numel(struct_in) > 1,
    for n0=1:numel(struct_in),
        struct_in(n0) = sub_replaceArg(struct_in(n0),string,replace);
    end
    struct_out = struct_in;
elseif iscell(struct_in) && numel(struct_in) > 1,
    for n0=1:numel(struct_in),
        struct_in{n0} = sub_replaceArg(struct_in{n0},string,replace);
    end
    struct_out = struct_in;
else
    fn = fieldnames(struct_in);
    for fn0=1:numel(fn),
        if isstruct(struct_in.(fn{fn0})) && numel(struct_in.(fn{fn0})) > 1,
            for n0=1:numel(struct_in.(fn{fn0})),
                struct_in.(fn{fn0})(n0) = sub_replaceArg(struct_in.(fn{fn0})(n0),string,replace);
            end
        elseif isstruct(struct_in.(fn{fn0}))
            struct_in.(fn{fn0}) = sub_replaceArg(struct_in.(fn{fn0}),string,replace);
        elseif ischar(struct_in.(fn{fn0}))
            struct_in.(fn{fn0}) = regexprep(struct_in.(fn{fn0}),string,replace);
        end
    end
    struct_out = struct_in;
end

function trial = sub_createPauseTrial(trial,struct_in,CTAinfo)
trial.TYPE  = 'pause';
try trial.PROMPT = struct_in.ATTRIBUTE.prompt; catch CTAinfo.warning('Missing prompt'); end
if isempty(trial.PROMPT)
    trial.PROMPT = 'PAUSE';
end
trial.STIM.HTML = cat(2,CTAinfo.prehtml,struct_in.CDATA_SECTION,CTAinfo.posthtml);

function trial = sub_createDummyTrial(trial,struct_in,info)
trial.TYPE  = 'dummy';
trial.STIM.HTML = html;

function trial = sub_createTrial(trial,trialinfo,CTAinfo)
CTAwarning = CTAinfo.warning;
try trial.TYPE      = trialinfo.ATTRIBUTE.type; catch error('Missing trial type'); end
try trial.DUR       = trialinfo.ATTRIBUTE.dur; catch CTAwarning('Missing trial dur'); end
try trial.ISI       = trialinfo.ATTRIBUTE.isi; catch CTAwarning('Missing trial isi'); end
try trial.HW        = trialinfo.ATTRIBUTE.hw; catch CTAwarning('Missing trial hw'); end
try trial.PROMPT    = trialinfo.ATTRIBUTE.prompt; catch CTAwarning('Missing trial prompt'); end


if strcmpi(trial.TYPE,'record'),
    flag = 'X';cond = 'XX';block = 0;rep = 0;
    try trial.FNAME     = trialinfo.ATTRIBUTE.mnemonic; catch error('Missing trial mnemonic'); end
    try flag            = trialinfo.ATTRIBUTE.flag; catch CTAwarning('Missing trial flag'); end
    try cond            = trialinfo.ATTRIBUTE.cond; catch CTAwarning('Missing trial cond'); end
    try block           = trialinfo.ATTRIBUTE.block; catch CTAwarning('Missing trial block'); end
    try rep             = trialinfo.ATTRIBUTE.rep; catch CTAwarning('Missing trial rep'); end
    trial.FNAME = [trial.FNAME,'_',flag,'_',cond,'_',sprintf('%02d_%02d',block,rep)];
end
for s0=1:numel(trialinfo.STIMULI)
    try trial.STIM(s0).DELAY = trialinfo.STIMULI(s0).ATTRIBUTE.delay; catch CTAwarning('missing delay'); end
    try trial.STIM(s0).RECORD = trialinfo.STIMULI(s0).ATTRIBUTE.record; catch CTAwarning('missing record'); end
    try trial.STIM(s0).HTML  = cat(2,CTAinfo.prehtml,trialinfo.STIMULI(s0).HTML.CDATA_SECTION,CTAinfo.posthtml); catch CTAwarning('missing html'); end
    try
		e0 = 1;
%         for e0=1:numel(trialinfo.STIMULI(s0).EXTRA),
            try trial.STIM(s0).EXTRA(s0).HANDLER = trialinfo.STIMULI(s0).EXTRA(e0).HANDLER; catch CTAwarning('missing handler'); end
            try trial.STIM(s0).EXTRA(s0).CONTENT = trialinfo.STIMULI(s0).EXTRA(e0).CONTENT; catch CTAwarning('missing content'); end
%         end
    catch
        CTAwarning('missing extra');
    end
end

%% Randomizers

function idx = randomize(idx)
idx = idx(:);
idx = idx(randperm(numel(idx))');

function idx = blockrandom(idx)
N = size(idx,1);
for i0=1:size(idx,2),
    idx(:,i0) = idx(randperm(N)',i0);
end
