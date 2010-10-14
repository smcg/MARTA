function hGroupContainer = setFigDockGroup(varargin)
% setFigDockGroup Sets a figure's docking group container
%
% Syntax:
%    hGroupContainer = setFigDockGroup(hFig, group)
%
% Description:
%    setFigDockGroup sets a figure's (or list of figures') docking group
%    container, enabling to dock figures to containers other than the
%    default 'Figures' container (for example, to the 'Editor' group, or
%    to any new user-defined group).
%
%    Changing docked figure(s)'s group will automatically transfer the
%    specified figure(s) to the new group container. Changing undocked
%    figure(s)'s group has no immediate visible effect (until the next
%    docking, when the figure(s) will dock into the new group).
%
%    Note: Matlab automatically updates the group's toolbar and menu based
%    on the component currently in focus. So even if you dock a figure onto
%    the Editor, when you focus on the figure you'll see the familiar figure
%    menu & toolbar - not the text editor's.
%
% Inputs:
%    hFig is an optional handle or list of handles. These are normally
%    figure handles, but not necessarily: the handles' containing figures
%    are automatically inferred and used. If hFig is not supplied, then
%    the current figure handle (gcf) is assumed.
%
%    GROUP is a mandatory string - the case-ensitive name of the requested
%    group container. If GROUP does not yet exist, then a new group by this
%    name is created (the pre-existing groups are: 'Editor', 'Figures',
%    'Web Browser', 'Array Editor', 'File Comparisons'). Note that docking
%    figures in some pre-existing groups (e.g., 'Web Browser') works but
%    look weird... GROUP may also be a group handle - the hGroupContainer
%    output of a previous setFigDockGroup function call.
%
% Outputs:
%    The returned hGroupContainer object allows access to many useful
%    properties and callbacks. Type "get(hGroupContainer)" to see the full
%    list.
%
% Examples:
%    setFigDockGroup(gcf,'Editor');  % dock current figure to Editor group
%    setFigDockGroup(gcf,'my new group');  % dock fig to a new user group
%    setFigDockGroup('my new group');  % same as above (gcf is inferred)
%    hGroup = setFigDockGroup(gcf,'Editor');  % get handle to group container
%    setFigDockGroup(gcf,hGroup);  % use previously-specified group container
%
% Side Effects:
%    The requested container becomes visible, unless it is undocked AND
%    does not contain any docked components.
%
% Warning:
%    This code heavily relies on undocumented and unsupported Matlab
%    functionality. It works on Matlab 7.4, but use at your own risk!
%
% Bugs and suggestions:
%    Please send to Yair Altman (altmany at gmail dot com)
%
% Change log:
%    2007-09-30: First version posted on <a href="http://www.mathworks.com/matlabcentral/fileexchange/loadAuthor.do?objectType=author&mfx=1&objectId=1096533#">MathWorks File Exchange</a>
%
% See also:
%    gcf, <a href="http://tinyurl.com/32alwt">getJFrame</a>, <a href="http://tinyurl.com/2fleuf">setDesktopVisibility</a> (last two on the File Exchange)
%    <a href="http://tinyurl.com/32q6hb">how to modify group container size/docking etc.</a> (comments #9,11)

% Programmed by Yair M. Altman: altmany(at)gmail.com
% $Revision: 1.0 $  $Date: 2007/09/30 01:29:44 $

  try
      % Sanity checks before starting...
      error(nargchk(1,inf,nargin,'struct'));

      % Require Java engine to run
      if ~usejava('jvm')
          error([mfilename ' requires Java to run.']);
      end

      % Default figure = current (gcf)
      hFig = varargin{1};
      if isjava(hFig) || ischar(hFig)
          hFig = gcf;
      elseif isempty(hFig) || ~all(ishghandle(hFig))
          error('hFig must be a valid GUI handle or array of handles');
      else
          % Valid HG handles
          varargin(1) = [];  % remove hFig entry
      end

      % Get the group (create new group if necessary)
      if isempty(varargin)
          error('Must supply a valid group name or handle');
      end
      group = varargin{1};
      desktop = getDesktop;  % = com.mathworks.mde.desk.MLDesktop.getInstance;
      % Only add a new group if group name (not handle) was supplied
      if ischar(group)
          currentGroupNames = cell(desktop.getGroupTitles);
          if ~any(strcmp(group,currentGroupNames))
              desktop.addGroup(group);
          end
      else
          % Extract group name from the container's userdata
          % Note: using group.getName is more elegant, but might mess us default groups
          group = get(group,'userdata');
      end

      % Temporarily dock first figure into the group, to ensure container creation
      % Note side effect: group container becomes visible
      hFig1 = getHFig(hFig(1));
      set(getJFrame(hFig1),'GroupName',group);
      oldStyle = get(hFig1,'WindowStyle');
      set(hFig1,'WindowStyle','docked');  drawnow
      set(hFig1,'WindowStyle',oldStyle);  drawnow

      % Loop over all other requested figures (if any)
      for figIdx = 2 : length(hFig)
          % Get the root Java frame
          jff = getJFrame(hFig(figIdx));
          % Set the frame's docking group to the selected group name
          set(jff,'GroupName',group);
      end

      % Get the group container
      hContainer = desktop.getGroupContainer(group);

      % Preserve the group name in the container's userdata, for future use by user
      set(hContainer,'userdata',group);

      % Hide the group container if it's undocked AND empty (no docked figures)
      if strcmp(get(desktop.getGroupLocation(group),'Docked'),'off') && ...
         hContainer.getComponent(1).getComponentCount == 0
           % Hide the group container
           hContainer.getTopLevelAncestor.hide;
      end

      % Initialize output var, if requested
      if nargout
          hGroupContainer = hContainer;
      end

  % Error handling
  catch
      v = version;
      if v(1)<='6'
          err.message = lasterr;  % no lasterror function...
      else
          err = lasterror;
      end
      try
          err.message = regexprep(err.message,'Error using ==> [^\n]+\n','');
      catch
          try
              % Another approach, used in Matlab 6 (where regexprep is unavailable)
              startIdx = findstr(err.message,'Error using ==> ');
              stopIdx = findstr(err.message,char(10));
              for idx = length(startIdx) : -1 : 1
                  idx2 = min(find(stopIdx > startIdx(idx)));  %#ok ML6
                  err.message(startIdx(idx):stopIdx(idx2)) = [];
              end
          catch
              % never mind...
          end
      end
      if isempty(findstr(mfilename,err.message))
          % Indicate error origin, if not already stated within the error message
          err.message = [mfilename ': ' err.message];
      end
      if v(1)<='6'
          while err.message(end)==char(10)
              err.message(end) = [];  % strip excessive Matlab 6 newlines
          end
          error(err.message);
      else
          rethrow(err);
      end
  end

%% Get the Java desktop reference
function desktop = getDesktop
  try
      desktop = com.mathworks.mde.desk.MLDesktop.getInstance;      % Matlab 7+
  catch
      desktop = com.mathworks.ide.desktop.MLDesktop.getMLDesktop;  % Matlab 6
  end

%% Get the Matlab HG figure handle for a given handle
function hFig = getHFig(handle)
  hFig = ancestor(handle,'figure');
  if isempty(hFig)
      error(['Cannot retrieve the figure handle for handle ' num2str(handle)]);
  end

%% Get the root Java frame (up to 10 tries, to wait for figure to become responsive)
function jframe = getJFrame(hFigHandle)

  % Ensure that hFig is a figure handle...
  hFig = getHFig(hFigHandle);

  jframe = [];
  maxTries = 10;
  while maxTries > 0
      try
          % Get the figure's underlying Java frame
          jframe = get(hFig,'javaframe');
          if ~isempty(jframe)
              break;
          else
              maxTries = maxTries - 1;
              drawnow; pause(0.1);
          end
      catch
          maxTries = maxTries - 1;
          drawnow; pause(0.1);
      end
  end
  if isempty(jframe)
      error(['Cannot retrieve the java frame for handle ' num2str(hFigHandle)]);
  end
