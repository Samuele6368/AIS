classdef helperAISViewer < handle
    %AISViewer AIS message viewer
    %   V = helperAISViewer creates a AIS message viewer object that
    %   processes message packets to be displayed on GUI, map, and saved in a
    %   text file.
    %
    %   helperAISViewer methods:
    %
    %   update(V,MSG) displays the contents of the AIS
    %   messages in the message vector, MSG.
    %
    %   startDataLog(V) starts data logging to a text file.
    %
    %   startMapUpdate(V) starts map updates.
    %
    %   start(V) starts message viewer, V. V captures the absolute start
    %   time, which is used to calculate the absolute reception time of each
    %   packet. Once started, message viewer updates the GUI every second
    %   and, if launched, the map every 10 seconds.
    %
    %   stop(V) stops message viewer, V.
    %
    %   See also AISExample, AISExampleApp, helperAISRxPhy.

    %   Copyright 2018-2022 The MathWorks, Inc.

    properties
        LogFileName = 'ais_messages.txt'
        Detected = 0
        Decoded = 0
        SignalSourceType = ExampleSourceType.Captured
        RadioAddress = 0
    end

    properties (Hidden)
        isInApp = false
        Lost = 0
    end
    properties (SetAccess = private, Dependent)
        StartTime
        LogData
    end
    properties (Access = private)
        pRawStartTime = 0
        pTableData
        pFileHandle = -1
        pFigureHandle = -1
        pParentHandle = -1
        pGUIHandles
        pLaunchMapvalue = 0
        pLogDatavalue = 0
        pFieldsToShow = {'ShipID', 'Latitude', ...
                        'Longitude', 'Date', 'Time'}
        pFieldsToShowIndices
        pProgressBar
        pMap
        pDispStr
    end
    properties (Access = private, Dependent)
        MapShips
    end
    properties (Constant, Access = private)
        MaxNumMessages = 15
        MapZoomLevel = 10
        CheckMark = char(10003)
    end

    methods
        function obj = helperAISViewer(varargin)
            p = inputParser;
            addParameter(p, 'SignalSourceType', ExampleSourceType.Captured);
            addParameter(p,'LogFileName','ais_messages.txt');
            addParameter(p,'ParentHandle',-1);
            addParameter(p, 'isInApp', false);
            parse(p,varargin{:});
            obj.LogFileName = p.Results.LogFileName;
            obj.SignalSourceType = p.Results.SignalSourceType;
            obj.pParentHandle = p.Results.ParentHandle;
            obj.isInApp = p.Results.isInApp;

            renderGUI(obj);
            reset(obj);
            [~,dataFieldNames] = enumeration('AISFieldNames');
            for p=1:length(obj.pFieldsToShow)
                obj.pFieldsToShowIndices(p) = ...
                    find(strcmpi(obj.pFieldsToShow{p}, dataFieldNames));
            end
        end
        function start(obj)
            setStartTime(obj);
            startProgressBar(obj)
        end
        function stop(obj)
            stopProgressBar(obj)
            stopDataLog(obj)
            stopMapUpdate(obj)
            % Flush map data
            updateMap(obj);
        end
        function reset(obj)
            [~,dataFieldNames] = enumeration('AISFieldNames');
            obj.pTableData = repmat({''},...
                obj.MaxNumMessages,length(dataFieldNames));
            for p=1:obj.MaxNumMessages
                obj.pTableData{p,AISFieldNames.Time} = 0;
            end
            initMapInfo(obj);
            obj.Lost = 0;
            obj.Decoded = 0;
            obj.Detected = 0;
        end
        function setStartTime(obj)
            obj.pRawStartTime = now;
        end
        function value = get.StartTime(obj)
            value = datestr(obj.pRawStartTime);
        end
        function flag = isStopped(obj)
            if isvalid(obj.pGUIHandles.ProgressIndicator) && ...
                    strcmp(obj.pGUIHandles.ProgressIndicator.String, 'Stopped')
                flag = true;
            else
                flag = false;
            end
        end
        function startProgressBar(obj)
            obj.pGUIHandles.ProgressIndicator.String  = 'Receiving';
            obj.pGUIHandles.DataLogging.Enable = 'on';
            start(obj.pProgressBar.Timer)
            drawnow;
        end
        function stopProgressBar(obj)
            obj.pGUIHandles.ProgressIndicator.String  = 'Stopped';
            obj.pGUIHandles.DataLogging.Enable  = 'off';
            stop(obj.pProgressBar.Timer)
            drawnow;
        end
        function startSourceStatus(obj)
            sigSrcType = obj.SignalSourceType;
            if strcmp(sigSrcType, 'Captured')
                dispStr = 'Selected file reader as the signal source';
            elseif strcmp(sigSrcType, 'RTLSDRRadio') || strcmp(sigSrcType, 'USRPRadio') || strcmp(sigSrcType, 'PlutoSDRRadio')
                dispStr = 'Checking radio connections...';
                count = 0;
                switch count
                    case 0
                        obj.pGUIHandles.ProgressIndicator.String = obj.pDispStr;
                    case 1
                        obj.pGUIHandles.ProgressIndicator.String = ...
                            [obj.pDispStr '.'];
                    case 2
                        obj.pGUIHandles.ProgressIndicator.String = ...
                            [obj.pDispStr '..'];
                    case 3
                        obj.pGUIHandles.ProgressIndicator.String = ...
                            [obj.pDispStr '...'];
                    case 4
                        obj.pGUIHandles.ProgressIndicator.String = ...
                            [obj.pDispStr '....'];
                    case 5
                        obj.pGUIHandles.ProgressIndicator.String = ...
                            [obj.pDispStr '.....'];
                end
                count = count + 1;
                count = mod(count,6);
                obj.pProgressBar.Count = count;
                drawnow
            end
            obj.pGUIHandles.ProgressIndicator.String  = dispStr;
            obj.pDispStr = dispStr;
            drawnow;
        end
        function stopSourceStatus(obj)
            sigSrcType = obj.SignalSourceType;
            if strcmp(sigSrcType, 'Captured')
                dispStr = 'Selected signal source: File';
            elseif strcmp(sigSrcType, 'RTLSDRRadio') % RTL-SDR radio
                dispStr = ['Connected to RTL-SDR with radio address: ',obj.RadioAddress];
            elseif strcmp(sigSrcType, 'USRPRadio')   % USRP radio
                dispStr = ['Connected to USRP with radio address: ',obj.RadioAddress];
            elseif strcmp(sigSrcType, 'PlutoSDRRadio') % ADALM-PLUTO radio
                dispStr = ['Connected to ADALM-PLUTO with radio address: ',obj.RadioAddress];
            end
            obj.pGUIHandles.ProgressIndicator.String  = dispStr;
            obj.pDispStr = dispStr;
            drawnow;
        end
        function radioConfigStatus(obj)
            sigSrcType = obj.SignalSourceType;
            if ~strcmp(sigSrcType, 'Captured')
                dispStr = 'Configuring radio parameters...';
                obj.pGUIHandles.ProgressIndicator.String  = dispStr;
                obj.pDispStr = dispStr;
                drawnow;
            end
        end
        function closeGUI(obj)
            if ishandle(obj.pFigureHandle) && isvalid(obj.pFigureHandle)
                close(obj.pFigureHandle)
            end
        end
        function value = get.LogData(obj)
            value = obj.pLogDatavalue;
        end
        function set.LogData(obj, value)
            obj.pLogDatavalue = value;
        end
        function value = get.MapShips(obj)
            value = obj.pLaunchMapvalue;
        end
        function update(obj, msg, pkt, lost)
            obj.Detected = obj.Detected + pkt.Detected;
            obj.Decoded = obj.Decoded + pkt.Decoded;
            if(msg.MMSI(1) == 0)
                msgCnt = 0;
            else
                msgCnt = pkt.Decoded;
            end
            msgStruct(1:msgCnt) = struct('MeassageBytes','','MMSI',0,'Longitude',0,'Latitude',0);
            for kk = 1:msgCnt
                msgStruct(kk).MessageBytes =  msg.MessageBytes(kk,:);
                msgStruct(kk).MMSI = msg.MMSI(kk);
                msgStruct(kk).Longitude = msg.Longitude(kk);
                msgStruct(kk).Latitude = msg.Latitude(kk);
            end
            
            updateRadioStatus(obj, lost);
            
            % --- INIZIO FIX AGGIORNAMENTO TABELLA ---
            % 1. PRIMA registriamo i nuovi dati della nave in memoria
            updateShipData(obj, msgStruct, msgCnt);
            
            % 2. POI aggiorniamo l'interfaccia grafica
            updateGUI(obj,msgCnt);
            
            % 3. FORZIAMO MATLAB a disegnare subito lo schermo senza aspettare
            drawnow limitrate; 
            % --- FINE FIX ---
            
            if msgCnt > 0
                if obj.LogData
                    write2File(obj, msgStruct, msgCnt);
                end
            end
        end
        function startDataLog(obj,logfilename)
            % Check if the file is already open
            if nargin == 1
                fileName = fopen(obj.pFileHandle);
                if ~strcmp(fileName, obj.LogFileName)
                    obj.pFileHandle = fopen(obj.LogFileName,'w');
                    if obj.pFileHandle ~= -1
                        obj.LogData = true;
                        fprintf(obj.pFileHandle, ['ShipID', '\t \t \t  Latitude', ...
                            '\t \t \t Longitude','\t \t \t\t \tMeassageBytes', '\t \t \t \t \t \t \t\tDate', '\t \t   Time\n']);
                    else
                        error(message('comm:examples:LogFileNotOpened',obj.LogFileName))
                    end
                end
            elseif nargin == 2
                obj.LogFileName = logfilename;
                fileName = fopen(obj.pFileHandle);
                if ~strcmp(fileName, obj.LogFileName)
                    obj.pFileHandle = fopen(obj.LogFileName,'w');
                    if obj.pFileHandle ~= -1
                        obj.LogData = true;
                        fprintf(obj.pFileHandle, ['ShipID', '\t \t \t  Latitude', ...
                            '\t \t \t Longitude','\t \t \t\t \tMeassageBytes', '\t \t \t \t \t \t \t\tDate', '\t \t   Time\n']);
                    else
                        error(message('comm:examples:LogFileNotOpened',obj.LogFileName))
                    end
                end
            end
        end
        function stopDataLog(obj)
            fileName = fopen(obj.pFileHandle);
            if strcmp(fileName, obj.LogFileName)
                fclose(obj.pFileHandle);
                obj.LogData = false;
                obj.pGUIHandles.DataLogging.String = 'Start Logging';
            end
        end
        function success = launchMap(obj)
            if exist('wmcenter', 'file') && license('checkout', 'map_toolbox')
                if ~isa(obj.pMap.Handle, 'map.webmap.Canvas') ...
                        || ~isvalid(obj.pMap.Handle)
                    % Create a timer object to periodically update the map
                    obj.pMap.Timer = timer(...
                        'BusyMode', 'drop', ...
                        'ExecutionMode', 'fixedRate', ...
                        'Name', 'MapUpdate', ...
                        'ObjectVisibility', 'off', ...
                        'Period', 20, ...
                        'StartDelay', 1, ...
                        'TimerFcn', @obj.updateMap);
                    % Open default map
                    obj.pMap.Handle = webmap;
                    addlistener(obj.pMap.Handle, 'ObjectBeingDestroyed', ...
                        @(src,event)closeMapCallback(obj, ...
                        obj.pMap.Timer));
                    % Check if we have any planes with airborne position information
                    tableData = obj.pTableData;
                    meanLat = 0;
                    meanLon = 0;
                    cnt = 0;
                    for idx = 1:obj.MaxNumMessages
                        if isa(tableData{idx,AISFieldNames.Latitude},'double')
                            if ~isnan(tableData{idx,AISFieldNames.Latitude})
                                meanLat = meanLat + tableData{idx,AISFieldNames.Latitude};
                                meanLon = meanLon + tableData{idx,AISFieldNames.Longitude};
                                cnt = cnt + 1;
                            end
                        end
                    end
                    if cnt > 0
                        wmcenter(meanLat/cnt, meanLon/cnt, obj.MapZoomLevel);
                    end
                    obj.pLaunchMapvalue = 1;
                    start(obj.pMap.Timer);
                end
                success = true;
            else
                success = false;
                msgbox(...
                    'This feature requires a valid license for Mapping Toolbox', ...
                    'AIS','modal')
            end
        end
        function closeMap(obj)
            if exist('wmcenter', 'file') 
                if isa(obj.pMap.Handle, 'map.webmap.Canvas') ...
                        && isvalid(obj.pMap.Handle)
                    wmclose(obj.pMap.Handle)
                    obj.pMap.FirstShip = false;
                    obj.pMap.MarkerData = zeros(obj.MaxNumMessages, 2);
                end
            end
        end
        function startMapUpdate(obj)
            success = launchMap(obj);
            if success && strcmp(obj.pMap.Timer.Running, 'off')
                start(obj.pMap.Timer);
            end
        end
        function stopMapUpdate(obj)
            if isa(obj.pMap.Timer, 'timer') && isvalid(obj.pMap.Timer) ...
                    && strcmp(obj.pMap.Timer.Running, 'on')
                stop(obj.pMap.Timer);
            end
        end
        function delete(obj)
            if ishandle(obj.pFigureHandle) && isvalid(obj.pFigureHandle)
                close(obj.pFigureHandle)
            end
        end
    end

    methods (Access = private)
        function updateGUI(obj,msgCnt)
            if ~isa(obj.pFigureHandle, 'matlab.ui.Figure') ...
                    || ~isvalid(obj.pFigureHandle)
                renderGUI(obj);
                startProgressBar(obj);
            end
            obj.pGUIHandles.AisMessagesDet.String = int2str(obj.Detected);
            obj.pGUIHandles.AisMessagesDecod.String = int2str(obj.Decoded);
            obj.pGUIHandles.AisMessagesPER.String = ...
                sprintf('%3.1f',100*(obj.Detected-obj.Decoded)/obj.Detected);
            if msgCnt>0
                tableData = obj.pTableData;
                for idx = 1:obj.MaxNumMessages
                    if strncmp(tableData{idx,AISFieldNames.ShipID},  '',1)
                        tableData{idx,AISFieldNames.Time} = '';
                    else
                    end
                end
                newTableData = tableData(:,obj.pFieldsToShowIndices);
                obj.pGUIHandles.DataTable.Data = newTableData;
            end
        end
        function updateRadioStatus(obj,lost)
            if ~isa(obj.pFigureHandle, 'matlab.ui.Figure') ...
                    || ~isvalid(obj.pFigureHandle)
                renderGUI(obj);
                startProgressBar(obj);
            end
            obj.Lost = lost;
            obj.pGUIHandles.LostFlag.String = int2str(obj.Lost);
        end
        function renderGUI(obj)
            if ~ishandle(obj.pParentHandle) || ~isvalid(obj.pParentHandle)
                obj.pFigureHandle = uifigure('Position', [100 100 870 500], ...
                    'Visible', 'off', ...
                    'HandleVisibility', 'on', ...
                    'Color', [0.8 0.8 0.8], ...
                    'MenuBar', 'none', ...
                    'Name', 'AIS Ship Tracking', ...
                    'IntegerHandle', 'off', ...
                    'NumberTitle', 'off', ...
                    'Tag', 'AIS', ...
                    'AutoResizeChildren', 'off');
                movegui(obj.pFigureHandle, 'center')
                obj.pParentHandle = uipanel(obj.pFigureHandle, ...
                    'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                    'Units', 'Normalized', 'Position', [0 0 1 1]);
            else
                obj.pFigureHandle = ancestor(obj.pParentHandle, 'figure');
            end
            % Set the object handle
            setappdata(obj.pFigureHandle, 'ViewerHandle', obj);
            % Create main container
            hMain = uipanel('Parent', obj.pParentHandle, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            % (1) Create the main grid
            hGridMain = siglayout.gridbaglayout(hMain);
            hGridMain.VerticalGap = 15;
            hGridMain.HorizontalGap = 15;
            % FIX: 4 righe -> 4 pesi (era [0 1 0], mancava il 4° elemento)
            hGridMain.VerticalWeights = [0 1 0 0];
            % (1.3) Lost flag
            hLateLost = uipanel(obj.pParentHandle, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            % Create a grid in 1.3
            hGridLateLost = siglayout.gridbaglayout(hLateLost);
            hGridLateLost.VerticalGap = 1;
            hGridLateLost.HorizontalGap = 5;
            hGridLateLost.HorizontalWeights = [0 0 1];
            % (1.3.1) Lost text
            hLostText = uicontrol(hLateLost, ...
                'Style', 'text', ...
                'String', 'Lost Flag:', ...
                'HorizontalAlignment', 'left', ...
                'Tag', 'Lost Text');
            add(hGridMain, hLateLost, 3, 1, ...
                'Fill', 'Both', ...
                'MinimumHeight', hLostText.Extent(4));
            add(hGridLateLost, hLostText, 1, 1, ...
                'Fill', 'Both', ...
                'MinimumWidth', hLostText.Extent(3));
            % (1.3.2) Lost value
            obj.pGUIHandles.LostFlag = uicontrol(hLateLost, ...
                'Style', 'text', ...
                'String', 'N/A', ...
                'HorizontalAlignment', 'left', ...
                'Tag', 'Lost Flag');
            add(hGridLateLost, obj.pGUIHandles.LostFlag, 1, 2, ...
                'Fill', 'Both', ...
                'MinimumWidth', 50);
            % (1.3.5) Empty space
            hEmpty = uipanel(hLateLost, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            add(hGridLateLost, hEmpty, 1, 3, ...
                'Fill', 'Both');
            % (1.1) Create data table
            obj.pGUIHandles.DataTable = uitable(obj.pParentHandle, ...
                'Data', repmat({'','','','',''},15,1), ...
                'ColumnName',...
                {'Ship ID','Latitude(deg)','Longitude(deg)',...
                'Date','Time'},...
                'ColumnWidth','auto',...
                'ColumnFormat', ...
                {'char','char','char','char','char',...
                }, ...
                'Tag', 'DataTable');
            add(hGridMain, obj.pGUIHandles.DataTable, 2, 1, ...
                'Fill', 'Both');
            % (1.1) Create Upper panel for packet statistics
            hUpperContainer = uipanel(obj.pParentHandle, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            % FIX: MinimumHeight aumentato da 70 a 95 per evitare
            % il taglio delle etichette "Detected / Decoded / PER(%)"
            add(hGridMain, hUpperContainer, 1, 1, ...
                'Fill', 'Both', ...
                'MinimumHeight', 95);
            % Create a grid in 1.1
            hGridUP = siglayout.gridbaglayout(hUpperContainer);
            hGridUP.VerticalGap = 1;
            hGridUP.HorizontalGap = 0;
            hGridUP.HorizontalWeights = [1 0];
            % (1.1.1) Create Packet statistics panel
            hPacketStats = uipanel(hUpperContainer, ...
                'Title', 'Packet statistics', 'AutoResizeChildren', 'off');
            add(hGridUP, hPacketStats, 1, 1, ...
                'Fill', 'Both');
            hGridStats = siglayout.gridbaglayout(hPacketStats);
            hGridStats.VerticalGap = 2;
            hGridStats.HorizontalGap = 5;
            hGridStats.HorizontalWeights = [0 1 1 1];
            hGridStats.VerticalWeights = [1 1 1 1];
            % (1.1.1.1) Empty
            hEmpty = uicontrol(hPacketStats, 'style', 'text');
            add(hGridStats, hEmpty, 1, 1, ...
                'Fill', 'Both', ...
                'TopInset', 20);
            % (1.1.1.2) Create AIS messages text
            hAisMessagesText = uicontrol(hPacketStats, ...
                'Style', 'text', ...
                'String', 'AIS packets:', ...
                'HorizontalAlignment', 'left', ...
                'Tag', 'AIS Message Text');
            add(hGridStats, hAisMessagesText, 2, 1, ...
                'Fill', 'Both', ...
                'TopInset', 3, ...
                'MinimumWidth', hAisMessagesText.Extent(3));
            % (1.1.1.5) Create detected text
            hDetectedText = uicontrol(hPacketStats, ...
                'Style', 'text', ...
                'String', 'Detected', ...
                'Tag', 'Detected Text');
            add(hGridStats, hDetectedText, 1, 2, ...
                'Fill', 'Both', 'TopInset', 20);
            % (1.1.1.6) Create short messages detected
            obj.pGUIHandles.AisMessagesDet = uicontrol(hPacketStats, ...
                'Style', 'edit', ...
                'String', '', ...
                'Enable', 'inactive', ...
                'Tag', 'AIS Message Detected');
            add(hGridStats, obj.pGUIHandles.AisMessagesDet, 2, 2, ...
                'Fill', 'Both');
            % (1.1.1.9) Create decoded text
            hDecodedText = uicontrol(hPacketStats, ...
                'Style', 'text', ...
                'String', 'Decoded', ...
                'Tag', 'Decoded Text');
            add(hGridStats, hDecodedText, 1, 3, ...
                'Fill', 'Both', 'TopInset', 20);
            % (1.1.1.10) Create short messages decoded
            obj.pGUIHandles.AisMessagesDecod = uicontrol(hPacketStats, ...
                'Style', 'edit', ...
                'String', '', ...
                'Enable', 'inactive', ...
                'Tag', 'AIS Message Decoded');
            add(hGridStats, obj.pGUIHandles.AisMessagesDecod, 2, 3, ...
                'Fill', 'Both');
            % (1.1.1.13) Create PER text
            hPERText = uicontrol(hPacketStats, ...
                'Style', 'text', ...
                'String', 'PER (%)', ...
                'Tag', 'Received Text');
            add(hGridStats, hPERText, 1, 4, ...
                'Fill', 'Both', 'TopInset', 20);
            % (1.1.1.14) Create short messages PER
            obj.pGUIHandles.AisMessagesPER = uicontrol(hPacketStats, ...
                'Style', 'edit', ...
                'String', '', ...
                'Enable', 'inactive', ...
                'Tag', 'AIS Message PER');
            add(hGridStats, obj.pGUIHandles.AisMessagesPER, 2, 4, ...
                'Fill', 'Both');
            % (1.4) Create container for progress bar
            hProgressBarContainer = uipanel(obj.pParentHandle, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            add(hGridMain, hProgressBarContainer, ...
                4, 1, ...
                'Fill', 'Both', ...
                'MinimumHeight', 20);
            % Create grid of the progress bar container
            hProgressBarContainerGrid = ...
                siglayout.gridbaglayout(hProgressBarContainer);
            hProgressBarContainerGrid.VerticalGap = 1;
            hProgressBarContainerGrid.HorizontalGap = 1;
            hProgressBarContainerGrid.HorizontalWeights = 1;
            % (1.4.1) Create container for progress bar indicator
            hProgressBarIndicatorContainer = ...
                uipanel(hProgressBarContainer, ...
                'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'Units', 'Normalized', 'Position', [0 0 1 1]);
            add(hProgressBarContainerGrid, hProgressBarIndicatorContainer, ...
                1, 1, ...
                'Fill', 'Both', ...
                'MinimumHeight', 20, ...
                'MinimumWidth', 230);
            % Create grid of the progress bar indicator container
            hProgressBarIndicatorContainerGrid = ...
                siglayout.gridbaglayout(hProgressBarIndicatorContainer);
            hProgressBarIndicatorContainerGrid.VerticalGap = 1;
            hProgressBarIndicatorContainerGrid.HorizontalGap = 1;
            hProgressBarIndicatorContainerGrid.VerticalWeights = 1;
            % (1.4.1.1) Progress bar indicator
            obj.pGUIHandles.ProgressIndicator = ...
                uicontrol(hProgressBarIndicatorContainer, ...
                'Style', 'text', ...
                'String', 'Stopped', ...
                'HorizontalAlignment', 'left', ...
                'ForegroundColor', 'blue', ...
                'Tag', 'ProgressBarIndicator');
            add(hProgressBarIndicatorContainerGrid, ...
                obj.pGUIHandles.ProgressIndicator, ...
                1, 1, ...
                'Fill', 'Both', ...
                'MinimumHeight', obj.pGUIHandles.ProgressIndicator.Extent(4), ...
                'MinimumWidth', obj.pGUIHandles.ProgressIndicator.Extent(3));
            initProgressBar(obj);
            obj.pFigureHandle.DeleteFcn = @obj.cleanupGUI;
            drawnow;
            obj.pFigureHandle.Visible = 'on';
        end
        function updateShipData(obj, msg, msgcnt)
            if msgcnt > 0
                tableData = obj.pTableData;
                updateTable = false;
                for p=1:msgcnt
                    currMsg = msg(p);
                    updateTable = true;
                    idx = strcmp(tableData(:,AISFieldNames.ShipID),'');
                    newIdx = find(idx);
                    index = newIdx(1);
                    idx = strcmp(tableData(:,AISFieldNames.ShipID),num2str(currMsg.MMSI));
                    if any(idx)
                        index = find(idx);
                    end
                    tableData{index,AISFieldNames.ShipID} = ...
                        num2str(currMsg.MMSI);
                    tableData{index,AISFieldNames.Latitude} = ...
                        currMsg.Latitude;
                    tableData{index,AISFieldNames.Longitude} = ...
                        currMsg.Longitude;
                    tableData{index,AISFieldNames.MeassageBytes} = ...
                        (currMsg.MeassageBytes);
                    tableData{index,AISFieldNames.Time} = ...
                        datestr(rem(now,1));
                    tableData{index,AISFieldNames.Date} = ...
                        datestr(floor(now));
                end
                if updateTable
                    obj.pTableData = tableData;
                end
            end
        end
        function write2File(obj,msg,pktCnt)
            if pktCnt > 0
                for p=1:pktCnt
                    currMsg = msg(p);
                    MMSI = currMsg.MMSI;
                    Latitude = currMsg.Latitude;
                    Longitude = currMsg.Longitude;
                    MsgBytes = currMsg.MessageBytes;
                    date = datestr(floor(now));
                    Time = datestr(rem(now,1));
                    fprintf(obj.pFileHandle, '\n%d\t %13.8f\t\t %13.8f\t\t %28s\t\t %s\t %s', MMSI, Latitude, Longitude, MsgBytes, date, Time);
                end
            end
        end
        function initMapInfo(obj)
            map.Handle = -1;
            map.MarkerHandles = cell(obj.MaxNumMessages,1);
            map.MarkerData = zeros(obj.MaxNumMessages, 2);
            map.ShipIconFolder = fileparts(mfilename('fullpath'));
            map.Timer = -1;
            map.FirstShip = false;
            obj.pMap = map;
        end
        function updateMap(obj,~,~)
            % Update map if only the user chose to open the map
            if obj.MapShips
                if isa(obj.pMap.Handle, 'map.webmap.Canvas') ...
                        && ~isvalid(obj.pMap.Handle)
                    launchMap(obj);
                else
                    tableData = obj.pTableData;
                    markerData = obj.pMap.MarkerData;
                    for idx = 1:obj.MaxNumMessages
                        % If this has lat/lon information and lat and lon are different
                        % than the one on the map then update the ship icon
                        lat = tableData{idx,AISFieldNames.Latitude};
                        lon = tableData{idx,AISFieldNames.Longitude};
                        if isa(lat,'double') && ~isnan(lat) ...
                                && (markerData(idx,1) ~= lat) ...
                                && (markerData(idx,2) ~= lon)
                            addShipToMap(obj, tableData(idx,:), idx);
                            markerData(idx,1) = lat;
                            markerData(idx,2) = lon;
                        end
                    end
                    obj.pMap.MarkerData = markerData;
                end
            end
        end
        function launchMapCallback(obj,src,~)
            if src.Value == 1
                success = launchMap(obj);
                if success
                    src.String = 'Close Map';
                else
                    src.Value = 0;
                end
            else
                src.String = 'Launch Map';
                closeMap(obj);
            end
        end
        function logDataCallback(obj,src,~)
            if src.Value == 1
                startDataLog(obj);
            else
                stopDataLog(obj);
            end
        end
        function addShipToMap(obj, shipData, markerIdx)
            shipID = shipData{AISFieldNames.ShipID};
            m = geopoint(shipData{AISFieldNames.Latitude},...
                shipData{AISFieldNames.Longitude});
            pngFolder = obj.pMap.ShipIconFolder;
            icon = fullfile( pngFolder , 'ship.png');
            if obj.pMap.FirstShip == false
                obj.pMap.FirstShip = true;
                wmcenter(shipData{AISFieldNames.Latitude},...
                    shipData{AISFieldNames.Longitude},obj.MapZoomLevel);
            end
            % First create a new marker
            tmpMarker = ...
                wmmarker(m,'Icon',icon,'FeatureName',['Ship # - ' num2str(shipID)]);

            if isa(obj.pMap.MarkerHandles{markerIdx}, 'map.webmap.MarkerOverlay') ...
                    && isvalid(obj.pMap.MarkerHandles{markerIdx})
                % Then delete the old one, if it exists
                wmremove(obj.pMap.MarkerHandles{markerIdx})
            end
            obj.pMap.MarkerHandles{markerIdx} = tmpMarker;
        end
        function removeShipFromMap(obj,markerIdx)
            if isa(obj.pMap.MarkerHandles{markerIdx}, 'map.webmap.MarkerOverlay') ...
                    && isvalid(obj.pMap.MarkerHandles{markerIdx})
                % Then delete the old one, if it exists
                wmremove(obj.pMap.MarkerHandles{markerIdx})
                markerData = obj.pMap.MarkerData;
                markerData(markerIdx,1) = 0;
                markerData(markerIdx,2) = 0;
                obj.pMap.MarkerData = markerData;
            end
        end
        function initProgressBar(obj)
            % Create a timer object for progress indicator
            count = 0;
            progressBar.Count = count;
            progressBar.Timer = timer(...
                'BusyMode', 'drop', ...
                'ExecutionMode', 'fixedRate', ...
                'Name', 'ShipAnimation', ...
                'ObjectVisibility', 'off', ...
                'Period', 1, ...
                'StartDelay', 1, ...
                'TimerFcn', @obj.updateProgressBar);
            obj.pProgressBar = progressBar;
        end
        function updateProgressBar(obj, ~, ~)
            %updateProgressBar AIS progress indicator
            %   updateProgressBar(T,~,~) creates a progress indicator on the GUI.
            count = obj.pProgressBar.Count;
            switch count
                case 0
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
                case 1
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
                case 2
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
                case 3
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
                case 4
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
                case 5
                    obj.pGUIHandles.ProgressIndicator.String = ['Receiving ' repmat('.',1,count)];
            end
            count = count + 1;
            count = mod(count,6);
            obj.pProgressBar.Count = count;
            drawnow
        end
        function cleanupGUI(obj,~,~)
            if isa(obj.pProgressBar.Timer,'timer') && isvalid(obj.pProgressBar.Timer)
                stop(obj.pProgressBar.Timer)
                delete(obj.pProgressBar.Timer)
            end
            if isa(obj.pMap.Timer,'timer') && isvalid(obj.pMap.Timer)
                stop(obj.pMap.Timer)
                delete(obj.pMap.Timer)
            end
            if isa(obj.pMap.Handle, 'map.webmap.Canvas') && isvalid(obj.pMap.Handle)
                wmclose(obj.pMap.Handle);
            end
        end
    end
end
function closeMapCallback(obj,hTimer)
obj.pLaunchMapvalue = 0;
obj.pMap.FirstShip = false;
obj.pMap.MarkerData = zeros(obj.MaxNumMessages, 2);
if isa(hTimer,'timer') && isvalid(hTimer)
    stop(hTimer)
    delete(hTimer)
end
end