function userInput = helperAISUserInput
%helperAISUserInput Gather user input for Automatic Identification System
%Example.
%   UIN = helperAISUserInput displays questions on the MATLAB command
%   window and collects user input, UIN. 
%
%   UIN is a structure of user inputs with following fields:
%
%   * Duration:         Run time of example
%   * RadioSampleRate:  Signal source sample rate
%   * RadioAddress:     Address string for radio (if radio is selected)
%   * SourceType:       Source type
%   * launchMap:        Flag to launch map at the start of example
%   * logData:          Flag to start logging at the start of example
%
%   See also AISExample

%   Copyright 2018 The MathWorks, Inc.

controller = helperAISController;

userInput = getUserInput(controller);
