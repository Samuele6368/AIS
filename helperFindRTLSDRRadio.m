function radioAddresses = helperFindRTLSDRRadio()
%helperFindRTLSDRRadio Find RTL-SDR radios connected to the host
%
% RADIOADDRESSES = helperFindRTLSDRRadio() returns a cell array (column)
% of radio address strings for each RTL-SDR device found.
% Returns empty cell if no device is found or the support package
% is not installed.

radioAddresses = {};

if ~exist('sdrrroot', 'file')
  warning('RTL-SDR support package not installed.');
  return;
end

try
  info = sdrinfo('RTL-SDR');
  if isempty(info)
    return;
  end
  % info può essere struct scalare o array di struct
  for k = 1:numel(info)
    if isfield(info(k), 'RadioAddress')
      radioAddresses{end+1,1} = info(k).RadioAddress; %#ok<AGROW>
    elseif isfield(info(k), 'Address')
      radioAddresses{end+1,1} = info(k).Address; %#ok<AGROW>
    end
  end
catch
  % Fallback: se sdrinfo non è disponibile prova con indirizzo di default
  try
    r = comm.SDRRTLReceiver('OutputDataType','single','SamplesPerFrame',1024);
    setup(r);
    release(r);
    radioAddresses = {'0'};
  catch
    radioAddresses = {};
  end
end

% Garantisce cell array colonna (Nx1)
radioAddresses = radioAddresses(:);

end