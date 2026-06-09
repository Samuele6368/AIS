classdef helperAISController < ExampleController
    
 %   Copyright 2018-2022 The MathWorks, Inc.
    
    properties (SetObservable, AbortSet)
        %LaunchMap Do you want to launch the map (Requires Mapping Toolbox)?
        LaunchMap = false
        CenterFrequency = 162.025e6;%MHz
    end
    properties (Access=protected, Constant)
        ExampleName = 'ShipTrackingUsingAISSignalsExample'
        ModelName = ''
        CodeGenCallback = @generateCodeCallback;
        MinContainerWidth = 270
        MinContainerHeight = 375
        Column1Width = 110
        Column2Width = 120
    end
    properties (Access=protected)
        HTMLFilename
        RunFunction = 'runAISReceiver'
    end

    methods
        function obj = helperAISController(varargin)
            obj@ExampleController(varargin{:});
            obj.HTMLFilename = 'comm/ShipTrackingUsingAISSignalsExample';
            obj.SignalFilename = 'ais_capture.bb';
            obj.LogFilename = 'ais_messages.txt';
            obj.ExampleTitle = 'AIS';
        end
        function set.LaunchMap(obj, aFlag)
            validateattributes(aFlag,{'logical'},...
                {'scalar'},...
                '', 'LaunchMap');
            obj.LaunchMap = aFlag;
        end
        function set.CenterFrequency(obj, aFrequency)
            try
                validateattributes(aFrequency,{'numeric'},...
                    {'scalar','real','finite','nonnan','positive'},...
                    '', 'CenterFrequency');
                obj.CenterFrequency = aFrequency;
            catch me
                handleErrorsInApp(obj.SignalSourceController,me)
            end
        end
    end

   methods 
    function flag = isInactiveProperty(obj,prop)
      if (strcmp(obj.SignalSourceController.SignalSource, 'File') && strcmp(prop, 'CenterFrequency')) 
        flag = true;
      else
        flag = isInactiveProperty@ExampleController(obj, prop);
      end
    end
  end

    methods (Access = protected)
        function addWidgets(obj)
            obj.addRow('Duration', 'Duration', 'edit', 'numeric');
            obj.addRow('SignalSource', 'Signal source', 'popupmenu');
            obj.addRow('RadioAddress', 'Radio address', 'popupmenu');
            obj.addRow('SignalFilename', 'Signal file name', 'edit', 'text');
            obj.addRow('CenterFrequency', 'Center Frequency', 'edit', 'numeric');
            obj.addRow('LaunchMap', 'Launch map', 'checkbox');
            obj.addRow('LogData', 'Log data', 'checkbox');
            obj.addRow('LogFilename', 'Log file name', 'edit', 'text');
        end

        function getUserInputImpl(obj)
            getCenterFrequency(obj);
            getLaunchMap(obj);
            getLogData(obj.LogDataController);
            getLogFilename(obj.LogDataController);
        end

        function getLaunchMap(obj)
            launchMapAns = input(...
                '\n> Do you want to launch the map (Requires Mapping Toolbox) [n]: ', 's');
            if isempty(launchMapAns)
                obj.LaunchMap = false;
            else
                if startsWith(launchMapAns, 'y')
                    obj.LaunchMap = true;
                elseif startsWith(launchMapAns, 'n')
                    obj.LaunchMap = false;
                else
                    error(message('comm:examples:Exit'));
                end
            end
        end

        function getCenterFrequency(obj)
            if ~isInactiveProperty(obj, 'CenterFrequency')
                freq = input(...
                    sprintf('\n> Enter AIS center frequency (Hz) [%e]: ',...
                    obj.CenterFrequency));
                if isempty(freq)
                    freq = obj.CenterFrequency;
                end
                obj.CenterFrequency = freq;
            end
        end
    end
end
function generateCodeCallback(userInput)
if isempty(which('helperAISRxPhy_mex'))
    aisParam = helperAISConfig(userInput);
    codegen(which('helperAISRxPhy'), '-args', {complex(single(zeros(aisParam.SamplesPerFrame, 1))), aisParam});
end
end
