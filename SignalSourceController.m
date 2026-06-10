classdef SignalSourceController < matlab.System
  %SignalSourceController Signal source controller
  %   Copyright 2016-2022 The MathWorks, Inc.

  properties (SetObservable, AbortSet, Nontunable)
    Duration      = 10
    SignalSource  = 'File'
    SignalFilename = 'example.bb'
  end

  properties (Access = public, Nontunable)
    ExampleTitle
  end

  properties (SetObservable, AbortSet, Nontunable, Dependent)
    RadioAddress
  end

  properties (Dependent, SetAccess = private)
    SignalSourceType
  end

  properties (Access = private)
    RTLSDRRadioAddress
    PlutoSDRRadioAddress
    USRPRadioAddress
  end

  properties (Hidden, Transient)
    SignalSourceSet = matlab.system.internal.DynamicStringSet({'File','RTL-SDR','ADALM-PLUTO','USRP'});
    RadioAddressSet = matlab.system.internal.DynamicStringSet({'0'});
  end

  methods

    function obj = SignalSourceController(varargin)
      obj.SignalSourceSet = matlab.system.internal.DynamicStringSet({'File','RTL-SDR','ADALM-PLUTO','USRP'});
      obj.RadioAddressSet = matlab.system.internal.DynamicStringSet({'0'});
      setProperties(obj, nargin, varargin{:});
    end

    function set.Duration(obj, aDuration)
      try
        validateattributes(aDuration, {'numeric'}, ...
          {'nonempty','scalar','positive','real','nonnan'}, '', 'Duration');
        obj.Duration = aDuration;
      catch me
        handleErrorsInApp(obj, me)
      end
    end

    function set.SignalSource(obj, aSource)
      if strcmp(aSource, 'File')
        obj.SignalSource = aSource;
      else
        try
          radioAddresses = isRadioInstalled(obj, aSource);
          if isempty(radioAddresses)
            error('Unable to find %s radio. Check your radio connection and try again.', aSource);
          else
            obj.SignalSource = aSource;
            updateRadioAddress(obj, radioAddresses);
          end
        catch me
          handleErrorsInApp(obj, me)
        end
      end
    end

    function set.SignalFilename(obj, aFilename)
      try
        aFilename = convertStringsToChars(aFilename);
        validateattributes(aFilename, {'char'}, {'nonempty','row'}, '', 'SignalFilename');
        obj.SignalFilename = aFilename;
      catch me
        handleErrorsInApp(obj, me)
      end
    end

    function out = isRadioInstalled(obj, aSource)
      if strcmp(aSource, 'RTL-SDR')
        if ~exist('sdrrroot', 'file')
          error('Hardware support package not installed. Open Home > Add-Ons and install Communications Toolbox Support Package for RTL-SDR Radio');
        else
          out = helperFindRTLSDRRadio();
        end
      elseif strcmp(aSource, 'ADALM-PLUTO')
        if isempty(which('plutoradio.internal.getRootDir'))
          error('Hardware support package not installed. Open Home > Add-Ons and install Communications Toolbox Support Package for ADALM-PLUTO Radio');
        else
          out = helperFindPlutoSDR();
        end
      elseif strcmp(aSource, 'USRP')
        if ~exist('sdruroot', 'file')
          error('Hardware support package not installed. Open Home > Add-Ons and install Communications Toolbox Support Package for USRP Radio');
        else
          out = helperFindUSRPRadio();
        end
      else
        out = {};
      end
    end

    function handleErrorsInApp(obj, errormsg)
      errordlg(errormsg.message, obj.ExampleTitle, 'Modal');
    end

    function aType = get.SignalSourceType(obj)
      switch obj.SignalSource
        case 'File';            aType = ExampleSourceType.Captured;
        case 'RTL-SDR';         aType = ExampleSourceType.RTLSDRRadio;
        case 'Simulated signal'; aType = ExampleSourceType.Simulated;
        case 'ADALM-PLUTO';     aType = ExampleSourceType.PlutoSDRRadio;
        case 'USRP';            aType = ExampleSourceType.USRPRadio;
        otherwise;              aType = ExampleSourceType.Captured;
      end
    end

    function aRadioAddr = get.RadioAddress(obj)
      if strcmp(obj.SignalSource, 'ADALM-PLUTO')
        aRadioAddr = obj.PlutoSDRRadioAddress;
      elseif strcmp(obj.SignalSource, 'RTL-SDR')
        aRadioAddr = obj.RTLSDRRadioAddress;
      else
        aRadioAddr = obj.USRPRadioAddress;
      end
    end

    function set.RadioAddress(obj, aValue)
      if strcmp(obj.SignalSource, 'RTL-SDR')
        obj.RTLSDRRadioAddress = aValue;
      elseif strcmp(obj.SignalSource, 'ADALM-PLUTO')
        obj.PlutoSDRRadioAddress = aValue;
      else
        obj.USRPRadioAddress = aValue;
      end
    end
  end

  methods (Access = private)
    function updateRadioAddress(obj, radioAddresses)
      % FIX: DynamicStringSet.changeValues richiede un cell array COLONNA
      % (N×1). helperFindUSRPRadio e gli altri helper ritornano un cell
      % array RIGA (1×N), che causava "Expected input to be empty, scalar
      % or a column vector". La trasposizione (:) risolve per qualsiasi
      % numero di indirizzi trovati.
      radioAddresses = radioAddresses(:);

      % Controlla che ci siano indirizzi validi
      if isempty(radioAddresses)
        return;
      end

      % Recupera indirizzo corrente (può essere [] se mai impostato)
      currentAddr = obj.RadioAddress;
      if isempty(currentAddr)
        currentAddr = '';
      end

      if any(strcmp(radioAddresses, currentAddr))
        obj.RadioAddressSet.changeValues(radioAddresses, obj, 'RadioAddress', currentAddr);
      else
        obj.RadioAddressSet.changeValues(radioAddresses, obj, 'RadioAddress', radioAddresses{1});
      end
    end
  end

  methods
    function getDuration(obj)
      tEnd = input(sprintf('\n> Specify run time in seconds [%f]: ', obj.Duration));
      if isempty(tEnd)
        tEnd = obj.Duration;
      end
      validateattributes(tEnd, {'numeric'}, {'scalar','real','positive','nonnan'}, '', 'Run Time');
      obj.Duration = tEnd;
    end

    function getSignalSource(obj)
      value        = obj.SignalSource;
      defaultValue = obj.SignalSourceSet.getIndex(value);
      options      = obj.SignalSourceSet.getAllowedValues;

      prompt = sprintf('\n> Enter signal source.');
      for q = 1:length(options)
        prompt = sprintf('%s\n>\t%d) %s', prompt, q, options{q});
      end
      prompt = sprintf('%s\n>\n> Signal source [%d]: ', prompt, defaultValue);
      signalSourceNum = input(prompt);
      if isempty(signalSourceNum)
        signalSourceNum = 1;
      end
      if signalSourceNum > length(options)
        error('Signal source selection number must be a positive integer less than or equal to %d.', length(options));
      end

      selectedSource = options{signalSourceNum};
      if strcmp(selectedSource, 'RTL-SDR')
        radioAddresses = helperFindRTLSDRRadio();
        if isempty(radioAddresses)
          error('Unable to find an RTL-SDR radio. Check your radio connection and try again.');
        end
      elseif strcmp(selectedSource, 'ADALM-PLUTO')
        radioAddresses = helperFindPlutoSDR();
        if isempty(radioAddresses)
          error('Unable to find a Pluto SDR radio. Check your radio connection and try again.');
        end
      elseif strcmp(selectedSource, 'USRP')
        radioAddresses = helperFindUSRPRadio();
        if isempty(radioAddresses)
          error('Unable to find a USRP radio. Check your radio connection and try again.');
        end
      end

      obj.SignalSource = selectedSource;

      switch obj.SignalSource
        case 'File'
          filenameAns = input(sprintf('\n> Enter captured signal file name [%s]: ', obj.SignalFilename), 's');
          if ~isempty(filenameAns)
            obj.SignalFilename = filenameAns;
          end
        case 'RTL-SDR'
          fprintf('\nSearching for radios connected to your host computer...\n');
          radioAddress = obj.RadioAddressSet.getAllowedValues;
          radioCnt = 0;
          msg = ['\n> Enter the number corresponding to the radio you would like to use.'];
          for p = 1:length(radioAddress)
            radioCnt = radioCnt + 1;
            msg = sprintf('%s\n>\t%d) %s [Radio Address: %s]', msg, radioCnt, 'RTL-SDR', radioAddress{p});
          end
          if radioCnt > 0
            radioNum = input(sprintf('%s\n>> Radio [1]: ', msg));
            if isempty(radioNum)
              radioNum = 1;
            end
            if radioNum <= radioCnt
              obj.RadioAddress = radioAddress{radioNum};
            else
              error('Radio selection number must be a positive integer less than or equal to %d.', radioCnt);
            end
          else
            error('Unable to find an RTL-SDR radio. Check your radio connection and try again.');
          end
      end
    end
  end

  methods (Access = protected)
    function flag = isInactivePropertyImpl(obj, prop)
      switch prop
        case 'RadioAddress'
          flag = strcmp(obj.SignalSource,'File') || strcmp(obj.SignalSource,'Simulated signal');
        case 'SignalFilename'
          flag = ~strcmp(obj.SignalSource,'File');
        case 'SignalSourceType'
          flag = true;
        otherwise
          flag = false;
      end
    end
  end
end