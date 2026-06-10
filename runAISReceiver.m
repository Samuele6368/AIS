function radioTime = runAISReceiver(radioTime, userInput, viewer, doCodegen)
%runAISReceiver AIS receiver main loop
% Supporta: File .bb, RTL-SDR, ADALM-PLUTO, USRP

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

% Controlla se il file sorgente è cambiato
fname1 = ''; fname2 = '';
if ~isempty(sigSrcType) && sigSrcType == ExampleSourceType.Captured
  [~, fname1] = fileparts(userInput.SignalFilename);
  [~, fname2] = fileparts(sigSrc.Filename);
end
fileNameChanged = ~strcmp(fname1, fname2);

% --- Configurazione radio (solo se necessario) ---
if isempty(aisParam) || ...
    userInput.SignalSourceType ~= sigSrcType || ...
    (userInput.SignalSourceType == ExampleSourceType.Captured && fileNameChanged)

  [aisParam, sigSrc] = helperAISConfig(userInput);
  sigSrcType = userInput.SignalSourceType;
end

% ======================================================================
%  CICLO PRINCIPALE
% ======================================================================
if radioTime <= userInput.Duration

  lostFlag = false;
  rcv      = [];

  try
    if aisParam.isSourceRadio

      % --- RTL-SDR ---
      if aisParam.isSourceRTLSDRRadio
        [rcv, ~, lost, ~] = sigSrc();
        lostFlag = logical(lost);

      % --- ADALM-PLUTO ---
      elseif aisParam.isSourcePlutoSDRRadio
        [rcv, ~, lostFlag] = sigSrc();

      % --- USRP ---
      elseif aisParam.isSourceUSRPRadio
        [rcv, ~, lostFlag] = sigSrc();

      end

    else
      % --- File .bb ---
      rcv      = sigSrc();
      lostFlag = false;
    end

  catch me
    warning('runAISReceiver: errore acquisizione: %s', me.message);
    radioTime = radioTime + aisParam.FrameDuration;
    return;
  end

  % --- Protezione buffer vuoto ---
  if isempty(rcv)
    radioTime = radioTime + aisParam.FrameDuration;
    return;
  end

  % --- Normalizzazione I/Q → vettore colonna complesso single ---
  rcv_d = double(rcv);
  if size(rcv_d, 2) == 2
    % Il receiver ha restituito [I Q] come colonne separate
    rcv_final = complex(rcv_d(:,1), rcv_d(:,2));
  else
    rcv_final = rcv_d(:);   % già complesso o reale → forza colonna
  end

  % --- Estrae il primo blocco della dimensione attesa ---
  targetLen = aisParam.SamplesPerFrame;
  if length(rcv_final) >= targetLen
    rcv_chunk = rcv_final(1:targetLen);
  else
    rcv_chunk = rcv_final;
  end

  % --- Decodifica AIS ---
  try
    if doCodegen
      [info, pkt] = helperAISRxPhy_mex(complex(single(rcv_chunk)), aisParam);
    else
      [info, pkt] = helperAISRxPhy(complex(single(rcv_chunk)), aisParam);
    end
    update(viewer, info, pkt, lostFlag);
  catch ME
    fprintf('Salto frame: %s\n', ME.message);
  end

  radioTime = radioTime + aisParam.FrameDuration;

else
  % --- Fine sessione: rilascio risorse ---
  if ~isempty(sigSrc)
    try
      if isvalid(sigSrc)
        release(sigSrc);
      end
    catch
    end
  end
  clear logFlag mapFlag
end

end