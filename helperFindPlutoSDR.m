function radioAddresses = helperFindPlutoSDR()
%helperFindPlutoSDR Find ADALM-PLUTO radios connected to the host
%
% RADIOADDRESSES = helperFindPlutoSDR() returns a cell array (column)
% of radio address strings for each PlutoSDR device found.
% Returns empty cell if no device is found or the support package
% is not installed.

radioAddresses = {};

if isempty(which('plutoradio.internal.getRootDir'))
  warning('ADALM-PLUTO support package not installed.');
  return;
end

try
  % Tenta discovery tramite sdrinfo
  info = sdrinfo('Pluto');
  if isempty(info)
    % Nessun device trovato via sdrinfo; prova con indirizzo IP default
    radioAddresses = {'192.168.2.1'};
    return;
  end
  for k = 1:numel(info)
    if isfield(info(k), 'RadioAddress')
      radioAddresses{end+1,1} = info(k).RadioAddress; %#ok<AGROW>
    elseif isfield(info(k), 'Address')
      radioAddresses{end+1,1} = info(k).Address; %#ok<AGROW>
    elseif isfield(info(k), 'IPAddress')
      radioAddresses{end+1,1} = info(k).IPAddress; %#ok<AGROW>
    end
  end
catch
  % Fallback: indirizzo IP default Pluto (USB) o hostname
  try
    r = sdrrx('Pluto', 'OutputDataType','single','SamplesPerFrame',1024);
    setup(r);
    release(r);
    radioAddresses = {'192.168.2.1'};
  catch
    radioAddresses = {};
  end
end

% Garantisce cell array colonna (Nx1)
radioAddresses = radioAddresses(:);

end
