function radioTime = runAISReceiver(radioTime, userInput, viewer, doCodegen)
%runAISReceiver AIS receiver main loop
%   Copyright 2018-2022 The MathWorks, Inc.

persistent aisParam sigSrc sigSrcType mapFlag logFlag

% --- Inizializzazione log (solo al primo frame) --------------------------
if isempty(logFlag)
    logFlag = 1;
    if userInput.LogData
        startDataLog(viewer, userInput.LogFilename);
    end
end

% --- Inizializzazione mappa (solo al primo frame) ------------------------
if isempty(mapFlag)
    mapFlag = 1;
    if userInput.LaunchMap
        startMapUpdate(viewer);
        pause(1);
    end
end

% --- Controlla se il file sorgente è cambiato ---------------------------
fname1 = '';
fname2 = '';
if ~isempty(sigSrcType) && sigSrcType == ExampleSourceType.Captured
    [~, fname1] = fileparts(userInput.SignalFilename);
    [~, fname2] = fileparts(sigSrc.Filename);
end
fileNameChanged = ~strcmp(fname1, fname2);

% --- (Ri)crea gli oggetti se necessario ---------------------------------
if isempty(aisParam) || ...
        userInput.SignalSourceType ~= sigSrcType || ...
        (userInput.SignalSourceType == ExampleSourceType.Captured && fileNameChanged)
    [aisParam, sigSrc] = helperAISConfig(userInput);
    sigSrcType = userInput.SignalSourceType;
end

% --- Ciclo di ricezione -------------------------------------------------
if radioTime <= userInput.Duration

    % Acquisisci campioni dalla sorgente
    lostFlag = false;
    try
        if aisParam.isSourceRadio
            if aisParam.isSourceUSRPRadio            % USRP
                [rcv, ~, lostFlag] = sigSrc();
            elseif aisParam.isSourceRTLSDRRadio      % RTL-SDR
                [rcv, ~, lost, ~] = sigSrc();
                lostFlag = logical(lost);
            elseif aisParam.isSourcePlutoSDRRadio    % ADALM-PLUTO
                [rcv, ~, lostFlag] = sigSrc();
            end
        else
            rcv = sigSrc();
            lostFlag = false;
        end
    catch me
        % FIX 1: cattura errori di acquisizione radio (es. timeout USRP,
        % disconnessione) senza crashare l'intera app.
        % Mostra l'errore nel viewer e restituisce il radioTime corrente
        % per fare in modo che il loop principale tenti di continuare.
        warning('runAISReceiver:acquisitionError', ...
            'Errore acquisizione radio: %s', me.message);
        return
    end

    % FIX 2: forza vettore colonna.
    % USRP e altri SDR possono restituire vettori riga (1xN).
    % helperAISRxPhy e tutte le sue funzioni interne assumono (Nx1).
    % Senza questo, si ottiene "Expected input to be empty, scalar
    % or a column vector" o errori di concatenazione verticale.
    % FIX 2: forza vettore colonna e converte il formato del dato
    % FIX 2: forza vettore colonna e converte il formato del dato
    rcv = rcv(:);
    rcv = double(rcv); % <-- Assicura che i dati siano nel formato corretto per il PHY
    
    % FIX 3: Evita che i frame vuoti o incompleti (Buffer Underrun) facciano crashare il sistema
    if isempty(rcv) || length(rcv) ~= aisParam.SamplesPerFrame
        disp(['[DEBUG] Frame USRP anomalo scartato. Lunghezza ricevuta: ', num2str(length(rcv))]);
        radioTime = radioTime + aisParam.FrameDuration;
        return; % <-- FIX: Usciamo dalla funzione in anticipo per questo frame
    end

    % Decodifica PHY
    if doCodegen
        [info, pkt] = helperAISRxPhy_mex(rcv, aisParam);
    else
        [info, pkt] = helperAISRxPhy(rcv, aisParam);
    end

    % Aggiorna il viewer
    update(viewer, info, pkt, lostFlag);
    radioTime = radioTime + aisParam.FrameDuration;

else
    % --- Cleanup finale (chiamata con radioTime > Duration) --------------
    % FIX 3: controlla che sigSrc esista e sia rilasciabile prima di
    % chiamare release(), per evitare errori se la sorgente non è mai
    % stata inizializzata (es. stop premuto prima del primo frame).
    if ~isempty(sigSrc) && isvalid(sigSrc)
        try
            release(sigSrc);
        catch
            % ignora errori in release (es. oggetto già rilasciato)
        end
    end

    % FIX 4: clear esplicito delle variabili persistent.
    % Necessario per reinizializzare correttamente alla prossima Run.
    % Nell'originale questo avveniva solo se nargout < 1, ma in modalità
    % app nargout è sempre 1 (radioTime viene restituito), quindi le
    % variabili persistent non venivano mai pulite tra una Run e l'altra.
    clear logFlag mapFlag
end
end
% [EOF]