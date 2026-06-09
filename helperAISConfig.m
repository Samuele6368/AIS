function [aisParam,sigSrc] = helperAISConfig(varargin)
%helperAISConfig AIS system parameters
%   [AISPARAM,SIGSRC] = helperAISConfig() returns AIS system parameters [1],
%   AISPARAM and signal source parameters, SIGSRC. Signal source can be
%   either File or RTL-SDR or USRP(TM) or ADALM-PLUTO.
%
%   [AISPARAM,SIGSRC] = helperAISConfig(USERINPUT) returns AISPARAM and
%   SIGSRC, for the user specified input structure, USERINPUT.
%
%   USERINPUT is a structure containing the following fields:
%
%   * Duration:            Run time of example
%   * FrontEndSampleRate:  Signal source sampling rate
%   * RadioAddress:        Address string for radio (if radio is selected)
%   * SourceType:          Source type
%   * SignalFilename:      Baseband signal file name
%   * launchMap:           Flag to launch map at the start of example
%   * logData:             Flag to start logging at the start of example
%
%   See also AISExample, AISExampleApp.

%   Copyright 2018-2022 The MathWorks, Inc.

% References: [1] Technical characteristics for an automatic identification
% system using time division multiple access in the VHF maritime mobile
% frequency band.

% Check the number of input arguments
narginchk(0,1);

% AIS system parameters
symbolRate = 9600;                              % in Hz
samplesPerSymbol = 24;
sampleRate = symbolRate*samplesPerSymbol;       % in Hz
if nargin == 0
    userInput.Duration = 10;                    % in seconds
    userInput.FrontEndSampleRate = sampleRate;
    userInput.RadioAddress = '0';
    userInput.SignalSourceType = ExampleSourceType.Captured;
    userInput.SignalFilename = 'ais_capture.bb';
    userInput.CenterFrequency = 162.025e6;
    userInput.launchMap = 0;
    userInput.logData = 0;
else
    tmp = varargin{1};
    if isstruct(tmp) || isa(tmp, 'ExampleController')
        userInput = varargin{1};
    else
        userInput.Duration = 10;
        userInput.FrontEndSampleRate = tmp;
        userInput.RadioAddress = '0';
        userInput.SignalSourceType = ExampleSourceType.Captured;
        userInput.SignalFilename = 'ais_capture.bb';
        userInput.CenterFrequency = 162.025e6;
        userInput.launchMap = 0;
        userInput.logData = 0;
    end
end

% Create signal source
switch userInput.SignalSourceType
    case ExampleSourceType.Captured
        bbFileName = userInput.SignalFilename;
        sigSrc = comm.BasebandFileReader(bbFileName);
        frontEndSampleRate = sigSrc.SampleRate;
        aisParam.isSourceRadio = false;
        aisParam.isSourceRTLSDRRadio = false;
        aisParam.isSourceUSRPRadio = false;
        aisParam.isSourcePlutoSDRRadio = false;
        sigSrc.CyclicRepetition = true;
        sigSrc.SamplesPerFrame = 262144; % 2^18
        aisParam.FrameDuration = 0.23; % Time in seconds to read samples from *.bb file
    case ExampleSourceType.RTLSDRRadio
        frontEndSampleRate = symbolRate*samplesPerSymbol;
        sigSrc = comm.SDRRTLReceiver('CenterFrequency',userInput.CenterFrequency,...
                                     'EnableTunerAGC',false,...
                                     'TunerGain',60,...
                                     'SampleRate',sampleRate,...
                                     'OutputDataType','single',...
                                     'SamplesPerFrame',262144);
        aisParam.isSourceRadio = true;
        aisParam.isSourceRTLSDRRadio = true;
        aisParam.isSourceUSRPRadio = false;
        aisParam.isSourcePlutoSDRRadio = false;
        aisParam.FrameDuration =  sigSrc.SamplesPerFrame/frontEndSampleRate;
    case ExampleSourceType.USRPRadio
        frontEndSampleRate = symbolRate*samplesPerSymbol;
        connectedRadios = findsdru(userInput.RadioAddress);
        if strncmp(connectedRadios(1).Status, 'Success', 7)
            platform = connectedRadios(1).Platform;
            switch connectedRadios(1).Platform
                case {'B200','B210'}
                    address = connectedRadios(1).SerialNum;
                case {'N200/N210/USRP2','X300','X310','N300','N310','N320/N321'}
                    address = connectedRadios(1).IPAddress;
            end
        else
            address = '192.168.10.2';
            platform = 'N200/N210/USRP2';
        end
        aisParam.Platform = platform;
        if ismember(aisParam.Platform, ['N320/N321','N200/N210/USRP2','N300','N310'])
            frontEndSampleRate = 200e3;
        end
        switch platform
            case {'B200','B210'}
                sigSrc = comm.SDRuReceiver(...
                    'Platform', platform, ...
                    'SerialNum', address, ...
                    'MasterClockRate', 18.432e6, ...
                    'OutputDataType','single');
            case {'X300','X310'}
                sigSrc = comm.SDRuReceiver(...
                    'Platform', platform, ...
                    'IPAddress', address, ...
                    'MasterClockRate', 184.32e6, ...
                    'OutputDataType','single');
            case {'N320/N321'}
                sigSrc = comm.SDRuReceiver(...
                    'Platform', platform, ...
                    'IPAddress', address, ...
                    'MasterClockRate', 200e6, ...
                    'OutputDataType','single');
            case {'N300','N310'}
                sigSrc = comm.SDRuReceiver(...
                    'Platform', platform, ...
                    'IPAddress', address, ...
                    'MasterClockRate', 153.6e6, ...
                    'OutputDataType','single');
            case {'N200/N210/USRP2'}
                sigSrc = comm.SDRuReceiver(...
                    'Platform', platform, ...
                    'IPAddress', address, ...
                    'MasterClockRate', 100e6, ...
                    'OutputDataType','single');
        end
        sigSrc.DecimationFactor = sigSrc.MasterClockRate/frontEndSampleRate;
        sigSrc.Gain = 30;
        sigSrc.CenterFrequency = userInput.CenterFrequency;
        sigSrc.SamplesPerFrame = 262144;
        aisParam.MasterClockRate = sigSrc.MasterClockRate;
        aisParam.DecimationFactor = sigSrc.DecimationFactor;
        aisParam.Gain = sigSrc.Gain;
        aisParam.isSourceRadio = true;
        aisParam.isSourceRTLSDRRadio = false;
        aisParam.isSourceUSRPRadio = true;
        aisParam.isSourcePlutoSDRRadio = false;
        aisParam.FrameDuration =  sigSrc.SamplesPerFrame/frontEndSampleRate;
    case ExampleSourceType.PlutoSDRRadio
        frontEndSampleRate = symbolRate*samplesPerSymbol;
        sigSrc = sdrrx('Pluto', ...
            'CenterFrequency',userInput.CenterFrequency, ...
            'GainSource', 'Manual', ...
            'Gain', 30, ...
            'BasebandSampleRate', frontEndSampleRate,...
            'OutputDataType', 'single', ...
            'SamplesPerFrame', 262144);
        aisParam.isSourceRadio = true;
        aisParam.isSourceRTLSDRRadio = false;
        aisParam.isSourceUSRPRadio = false;
        aisParam.isSourcePlutoSDRRadio = true;
        aisParam.FrameDuration =  sigSrc.SamplesPerFrame/frontEndSampleRate;
    otherwise
        error('comm:examples:Exit', 'Aborted.');
end
aisParam.FrontEndSampleRate = frontEndSampleRate;
aisParam.SampleRate = frontEndSampleRate;
aisParam.SamplesPerSymbol = samplesPerSymbol;
aisParam.MinPacketLength = 184*samplesPerSymbol;% Minimum packet length as per standard is 184
aisParam.MaxPacketLength = 480*samplesPerSymbol;% Maximum packet length as per standard is 480
aisParam.windowLen = 1024;
% Calculate actual samples per frame based on the target number
aisParam.BT = 0.3;
aisParam.span = 3;
aisParam.Prehistory = [1 -1];
h = gaussdesign(aisParam.BT,aisParam.span,aisParam.SamplesPerSymbol);
aisParam.h = h/std(h);
aisParam.SamplesPerFrame = sigSrc.SamplesPerFrame;
aisParam.TrainingSeq = logical([1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]);
aisParam.TrainingSeqNRZI = logical([1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1]);
% Generate synchronization fields
[aisParam.syncSyms,aisParam.syncAngles] = helperAISSyncGen(aisParam);

end