function radioTime = runAISReceiver(radioTime, userInput, viewer, doCodegen)
%runAISReceiver AIS receiver main loop

persistent aisParam sigSrc sigSrcType mapFlag logFlag

% --- Inizializzazione log e mappa ---
if isempty(logFlag)
    logFlag = 1;
    if userInput.LogData
        startDataLog(viewer, userInput.LogFilename);
    end
end

if isempty(mapFlag)
    mapFlag = 1;
    if userInput.LaunchMap
        startMapUpdate(viewer);
        pause(1);
    end
end

fname1 = ''; fname2 = '';
if ~isempty(sigSrcType) && sigSrcType == ExampleSourceType.Captured
    [~, fname1] = fileparts(userInput.SignalFilename);
    [~, fname2] = fileparts(sigSrc.Filename);
end
fileNameChanged = ~strcmp(fname1, fname2);

% --- Configurazione Radio ---
if isempty(aisParam) || ...
        userInput.SignalSourceType ~= sigSrcType || ...
        (userInput.SignalSourceType == ExampleSourceType.Captured && fileNameChanged)
    
    [aisParam, sigSrc] = helperAISConfig(userInput);
    sigSrcType = userInput.SignalSourceType;
    
    if aisParam.isSourceUSRPRadio
        disp('[SYSTEM] Configurazione USRP B205mini completata. Avvio...');
        pause(2); 
    end
end

% --- Ciclo principale di ricezione ---
if radioTime <= userInput.Duration
    lostFlag = false;
    try
        if aisParam.isSourceRadio
            if aisParam.isSourceUSRPRadio            
                [rcv, ~, lostFlag] = sigSrc();
            elseif aisParam.isSourceRTLSDRRadio      
                [rcv, ~, lost, ~] = sigSrc();
                lostFlag = logical(lost);
            elseif aisParam.isSourcePlutoSDRRadio    
                [rcv, ~, lostFlag] = sigSrc();
            end
        else
            rcv = sigSrc();
            lostFlag = false;
        end
    catch me
        warning('Errore acquisizione: %s', me.message);
        radioTime = radioTime + aisParam.FrameDuration;
        return;
    end

    % --- SCUDO DI PROTEZIONE E FUSIONE I/Q ---
    if isempty(rcv)
        radioTime = radioTime + aisParam.FrameDuration;
        return; 
    end
    
    % --- BLOCCO DI FORZA BRUTA (CHIRURGICO) ---
    % 1. Trasformiamo in complesso (I+jQ) se necessario
    rcv_clean = double(rcv); 
    if size(rcv_clean, 2) == 2
        rcv_final = complex(rcv_clean(:,1), rcv_clean(:,2));
    else
        rcv_final = rcv_clean(:);
    end
    
    % 2. ESTRAZIONE CHIRURGICA:
    % Invece di passare TUTTO il buffer, ne prendiamo solo una fetta 
    % che abbia la dimensione esatta attesa dal demodulatore
    targetLen = aisParam.SamplesPerFrame;
    
    % Se abbiamo dati a sufficienza, estraiamo solo il primo blocco utile
    if length(rcv_final) >= targetLen
        rcv_chunk = rcv_final(1:targetLen);
    else
        rcv_chunk = rcv_final; % Passiamo quello che c'è
    end
    
    % 3. Decodifica "pura" con protezione
    try
        if doCodegen
            [info, pkt] = helperAISRxPhy_mex(rcv_chunk, aisParam);
        else
            [info, pkt] = helperAISRxPhy(rcv_chunk, aisParam);
        end
        update(viewer, info, pkt, lostFlag);
    catch ME
        % Silenziamo l'errore per non bloccare il loop radio
        fprintf('Salto frame: %s\n', ME.message);
    end
    % -----------------------------------------
    
    radioTime = radioTime + aisParam.FrameDuration;
else
    % Rilascio risorse
    if ~isempty(sigSrc) && isvalid(sigSrc)
        try release(sigSrc); catch; end
    end
    clear logFlag mapFlag
end
end
% [EOF]