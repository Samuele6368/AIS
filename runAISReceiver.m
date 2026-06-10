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

% --- Configurazione Radio e Attesa Boot ---
if isempty(aisParam) || ...
        userInput.SignalSourceType ~= sigSrcType || ...
        (userInput.SignalSourceType == ExampleSourceType.Captured && fileNameChanged)
    
    [aisParam, sigSrc] = helperAISConfig(userInput);
    sigSrcType = userInput.SignalSourceType;
    
    % --- FIX: ATTESA CARICAMENTO FPGA SUL B205MINI ---
    if aisParam.isSourceUSRPRadio
        disp('[SYSTEM] Caricamento FPGA sul B205mini in corso. Attendere 5 secondi...');
        pause(5); % Diamo all'USRP il tempo materiale di avviare il firmware!
        disp('[SYSTEM] USRP Avviato. Inizio decodifica...');
    end
    % -------------------------------------------------
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
        warning('Errore acquisizione radio: %s', me.message);
        radioTime = radioTime + aisParam.FrameDuration;
        return;
    end

    % --- SCUDO DI PROTEZIONE FRAME (Anti-Popup) ---
    if ~exist('rcv', 'var') || isempty(rcv) || length(rcv) ~= aisParam.SamplesPerFrame
        % Se il frame è vuoto o anomalo, lo ignoriamo silenziosamente
        radioTime = radioTime + aisParam.FrameDuration;
        return; 
    end
    
    % Forza la colonna solo se il frame è integro
    rcv = single(rcv(:));
    % ----------------------------------------------

    % --- INIZIO TRAPPOLA ERRORI ---
    % Ci assicuriamo che il formato sia esattamente quello atteso dai filtri ('single')
    if size(rcv, 2) > 1
        rcv = rcv(:, 1); % Prende solo il canale 1 se la matrice è anomala
    end
    rcv = single(rcv(:)); 

    try
        if doCodegen
            [info, pkt] = helperAISRxPhy_mex(rcv, aisParam);
        else
            [info, pkt] = helperAISRxPhy(rcv, aisParam);
        end
    catch ME
        disp(' ');
        disp('!!! CRASH INTERNO TROVATO !!!');
        disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
        disp('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        error('Decodifica fallita. Controlla la Command Window.');
    end
    % --- FINE TRAPPOLA ERRORI ---

    update(viewer, info, pkt, lostFlag);
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