classdef AISFieldNames < uint8
  %AISFieldNames AIS message field names
  %
  %   See also AISExample.

  %   Copyright 2018 The MathWorks, Inc.

  enumeration
      ShipID               (1)
      Latitude             (2)
      Longitude            (3)
      MeassageBytes        (4)
      Date                 (5)  
      Time                 (6)
  end
end
