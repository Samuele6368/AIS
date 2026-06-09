function varargout = AISExampleApp

figureHandle = uifigure('Visible', 'off', ...
    'HandleVisibility', 'on', ...
    'NumberTitle', 'off', ...
    'IntegerHandle', 'off', ...
    'MenuBar', 'none', ...
    'Name', 'Automatic Identification System (AIS)', ...
    'Tag', 'AISMLAppFigure', ...
    'AutoResizeChildren', 'off');

% ---- SOSTITUISCI uigridcontainer CON QUESTO ----
mainLayout = uigridlayout(figureHandle, [1 2]);
mainLayout.ColumnWidth = {270, '1x'};
mainLayout.RowHeight = {'1x'};
mainLayout.Padding = [0 0 0 0];
mainLayout.ColumnSpacing = 0;
mainLayout.RowSpacing = 0;
% ------------------------------------------------

controllerPanel = uipanel('Parent', mainLayout, ...
    'Tag', 'AISMLAppCtrlPanel', ...
    'AutoResizeChildren', 'off');

viewerPanel = uipanel('Parent', mainLayout, ...
    'Tag', 'AISMLAppViewerPanel', ...
    'AutoResizeChildren', 'off');

% Queste righe rimangono invariate
viewer = helperAISViewer('ParentHandle', viewerPanel, 'isInApp', true);
controller = helperAISController('ParentHandle', controllerPanel, ...
    'Viewer', viewer);
render(controller);
movegui(figureHandle, 'center');
drawnow
figureHandle.Position = [figureHandle.Position(1), figureHandle.Position(2), 900, 490];
drawnow
figureHandle.Visible = 'on';

if nargout > 0
    varargout{1} = controller;
end
if nargout > 1
    varargout{2} = viewer;
end
end