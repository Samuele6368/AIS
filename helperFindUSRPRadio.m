function address = helperFindUSRPRadio()
% helperFindUSRPRadio Find a USRP(TM) radio on the host computer
%   Copyright 2021-2022 The MathWorks, Inc.

% BUG FIX 1: address inizializzato subito a {} per evitare
% "undefined variable" se la funzione esce prima del loop
address = {};

% Verifica che il Support Package sia installato
if ~exist('sdruroot', 'file')
    link = sprintf(['<a href="https://www.mathworks.com/hardware-support' ...
        '/usrp.html">USRP Support From Communications Toolbox</a>']);
    error(['Unable to find Communications Toolbox Support Package ' ...
        'for USRP Radio. To install the support package, visit %s'], link);
end

% Ricerca dispositivi USRP connessi
rawDeviceList = getSDRuList();

% BUG FIX 2: rimosso il check "nargin == 0" (questa funzione non ha
% argomenti di input, quindi nargin e' sempre 0 -> il check era inutile
% e creava un ramo di codice morto)
% BUG FIX 3: aggiunto controllo isempty per rawDeviceList malformato
if strcmp(rawDeviceList, 'No devices found') || isempty(rawDeviceList)
    return;
end

% Rimuovi i caratteri null e tokenizza usando ',' come delimitatore
deviceList = [',' rawDeviceList(rawDeviceList ~= 0)];
tokIdx     = [strfind(deviceList, ','), length(deviceList) + 1];

% BUG FIX 4: uso floor() per la divisione intera — se la lista e'
% malformata, (length-1)/4 potrebbe non essere intero e causare un
% loop con indice frazionario
numDevices = floor((length(tokIdx) - 1) / 4);

if numDevices == 0
    return;
end

for p = 1:numDevices
    % Estrai i campi del dispositivo p-esimo
    ipAddress = deviceList(tokIdx(4*p-3)+1 : tokIdx(4*p-3+1)-1);
    typeStr   = deviceList(tokIdx(4*p-2)+1 : tokIdx(4*p-2+1)-1);
    serialNum = deviceList(tokIdx(4*p-1)+1 : tokIdx(4*p-1+1)-1);

    if strcmp(typeStr, 'usrp2')
        platform = 'N200/N210/USRP2';
    else
        platform = deviceList(tokIdx(4*p)+1 : tokIdx(4*p+1)-1);
    end

    % BUG FIX 5: aggiunto controllo length(platform) >= 2 prima di
    % accedere a platform(1:2) — senza questo check, un platform vuoto
    % o con un solo carattere causava un errore di indice fuori range
    if ~isempty(platform) && length(platform) >= 2 && strcmp(platform(1:2), 'B2')
        % Dispositivi B2xx: usa il numero seriale come indirizzo
        address{p} = serialNum; %#ok<AGROW>
    else
        % Tutti gli altri: usa l'indirizzo IP
        address{p} = ipAddress; %#ok<AGROW>
    end
end
end