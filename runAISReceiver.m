function radioTime = runAISReceiver(radioTime, userInput, viewer,doCodegen)

%   Copyright 2018-2022 The MathWorks, Inc.
persistent aisParam sigSrc sigSrcType mapFlag logFlag 

if isempty(logFlag)
    logFlag = 1;
    if (userInput.LogData)
        startDataLog(viewer, userInput.LogFilename);
    end
end
if isempty(mapFlag)
    mapFlag = 1;
    if (userInput.LaunchMap)
        startMapUpdate(viewer);
        pause(1);
    end
end
fname1 = '';
fname2 = '';

if ~isempty(sigSrcType) && sigSrcType == ExampleSourceType.Captured 
  [~, fname1] = fileparts(userInput.SignalFilename);
  [~, fname2] = fileparts(sigSrc.Filename);
end
fileNameChanged = ~strcmp(fname1, fname2);
% (re)create objects:
if isempty(aisParam) || ...
    userInput.SignalSourceType ~= sigSrcType|| ...
    ( userInput.SignalSourceType == ExampleSourceType.Captured && fileNameChanged )
    [aisParam, sigSrc] = helperAISConfig(userInput);
    sigSrcType = userInput.SignalSourceType;
end
if radioTime <= userInput.Duration

    if aisParam.isSourceRadio        
        if aisParam.isSourceUSRPRadio       % For USRP
            [rcv,~,lostFlag] = sigSrc();  
        elseif aisParam.isSourceRTLSDRRadio % For RTL-SDR
            [rcv,~,lost,~] = sigSrc();
            lostFlag = logical(lost);
        elseif aisParam.isSourcePlutoSDRRadio   % For ADALM-PLUTO
            [rcv,~,lostFlag] = sigSrc();
        end              
    else
        rcv = sigSrc();
        lostFlag = false;
    end
    if doCodegen
        [info, pkt] = helperAISRxPhy_mex(rcv, aisParam);
    else
         [info, pkt] = helperAISRxPhy(rcv, aisParam);
    end
    % View results packet contents (Data Viewer)
    update(viewer, info, pkt, lostFlag);
    radioTime = radioTime + aisParam.FrameDuration;
else
    if nargout < 1
        release(sigSrc);
        clear logFlag mapFlag;
    end
end
end
% [EOF]
