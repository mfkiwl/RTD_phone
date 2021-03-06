%% Initialization for GSARx receiver structure
function receiver = ReceiverInitializing()

receiver = struct( ...
    'syst',            [], ...
    'config',          [], ...
    'channels',        [], ...
    'satelliteTable',  [], ...
    'almanac',         [], ...
    'ephemeris',       [], ...
    'timer',           [], ...
    'preFilt',         [], ...
    'pvtCalculator',   [], ...
    'recorder',        [], ...
    'elapseTime',      [], ...
    'UI',              [], ...
    'device',          [] ...
);

% Default configuration
receiver.config = struct( ...
    'acqConfig',       [], ...
    'bitSyncConfig',   [], ...    
    'trackConfig',     [], ...
    'cadllConfig',     [] ... 
);

% Initialize the channels struct
receiver.channels = ChannelsInitializing(7); % 7 is a prn ID, just for initialization.

% Config the receiver inner-time module
receiver.timer = TimerInitializing();

% Config the pre-filtering module
receiver.preFilt = ConfigurePreFilter();

% Config UI parameters
receiver.UI = struct( ...
    'statusTable',          [], ...
    'position',             []  ...
    );

end