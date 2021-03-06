%% Initialization for channels struct
function channels = ChannelsInitializing(prn)

global GSAR_CONSTANTS;

%% PLL loop filter asisted by FLL Structure Definition, 9 components
STR_PLL.Bn  = 10;%10;       % PLL noise bandwidth, [Hz]
STR_PLL.Ord = 3;            % Loop order
STR_PLL.Fn  = 3;            % FLL noise bandwidth, [Hz]
STR_PLL.REG = zeros(4,1);   % Filter registers
STR_PLL.IQ_d = zeros(2,1);  % Storing previous prompt I,Q channel cumulative values
% LoopType: the PLL loop type.
% PLL_FEEDBACK:  using conventional feedback loop structure for locking carrier phase
% FLL_OPEN:      using open loop structure and maximal likelihood principle to do freq lock
STR_PLL.LoopType = 'PLL_FEEDBACK'; % PLL_FEEDBACK/FLL_OPEN/KALMAN
STR_PLL.freqstep_fllopen = 5; % the freq trial step when using FLL_OPEN type
STR_PLL.fllopen_binum = 5;  % the freq trial bins that are seperated by freqstep_fllopen Hz
STR_PLL.freqbin_reg_I = zeros(STR_PLL.fllopen_binum, 1);
STR_PLL.freqbin_reg_Q = zeros(STR_PLL.fllopen_binum, 1);

%% DLL loop filter Structure Definition
STR_DLL.Dn  = 1;          % DLL noise bandwidth, [Hz]
STR_DLL.Ord = 1;          % DLL 
STR_DLL.SPACING = 0.2;    % Early-Late correlator spacing, [chips]; 0.2 for unit 0 channel
STR_DLL.SPACING_MP = 0.2; % spacing for initialization of trail channel
STR_DLL.REG = zeros(4,1); % Filter registers
    
%% ALL loop filter structure definition (10 components)
STR_ALL.An        = 5;      % ALL noise bandwidth, [Hz]
STR_ALL.AFn       = 0.5;      % AFL noise bandwidth, [Hz]
STR_ALL.ai_v      = zeros(4,1); % I channel amplitude estimates
STR_ALL.ai_reg    = zeros(4,1); % I channel regs
STR_ALL.ai_freg   = zeros(4,1); % I channel freq regs
STR_ALL.aq_v      = zeros(4,1); % Q channel amplitude estimates
STR_ALL.aq_reg    = zeros(4,1); % Q channel regs
STR_ALL.aq_freg   = zeros(4,1); % Q channel freq regs
STR_ALL.lambda    = 1;
STR_ALL.NormSampN = 0; % The Counter used for normalizing the estimated amplitude of the singal
STR_ALL.TslotNormSampN = 0;  % The normalizing factor in a Tslot
% ALL kalman filter structure
STR_ALL.ai_kalfilt_state  = [0, 0]';
STR_ALL.ai_kalfilt_P      = zeros(2,2);
STR_ALL.aq_kalfilt_state  = [0, 0]';
STR_ALL.aq_kalfilt_P      = zeros(2,2);
STR_ALL.a_kalfilt_P0      = [1, 0.1]';
STR_ALL.a_kalfilt_Q       = [0.01, 0.01]';
STR_ALL.a_kalfilt_R       = 0.01;
% Define the registers of computing the averaged amplitude and its standard
% devirations.
STR_ALL.a_avg     = zeros(4,1); % a_avg(1) stores the averaged a; a_avg(2) stores the averaged ai; a_avg(3) stores the averaged aq;
STR_ALL.a_std     = zeros(3,1); % a_std(1) stores the std of a; a_std(2) stores the std of ai; a_std(3) stores the std of aq;
STR_ALL.acnt      = 0;          % SNR estimation counter
STR_ALL.SNR       = 0;

%% VTL kalman prefilter structure definition
% Error states of code phase \dtau, carrier phase \dtheta, doppler freq
% \df, accelaration \dalpha, amplitude_i \a_i, amplitude_i acceleration
% \a_i_dot, amplitude_q \a_q, amplitude_i acceleration \a_q_dot
STR_KalPreFilt.loopErrState = [0, 0, 0, 0]';
STR_KalPreFilt.P0 = [0.25, 1, 500, 10]';% diagnal values
STR_KalPreFilt.P  = zeros(4,4); % estimation error covariance
STR_KalPreFilt.Q  = [1e-2, 1e-3, 1e-2, 10]';% state process variance
STR_KalPreFilt.R  = [0.1, 0.1]';% measurement error variance
STR_KalPreFilt.firstFiltering = int32(1);% flag indicating first loop filtering

%% L1/L2C双频卡尔曼跟踪结构体定义
STR_KalPreFilt_plus = struct( ...
    'loopErrState',     zeros(6,1), ...  状态向量
    'A',                zeros(6),   ...
    'H',                zeros(6),   ...
    'P0',               zeros(6,1), ...  初始误差矩阵（对角）
    'P',                zeros(6),   ...  预测误差矩阵
    'Q',                zeros(6,1), ...  连续型过程噪声矩阵
    'Qd',               zeros(6),   ...  离散型过程噪声矩阵
    'R',                zeros(6,1), ...  测量误差矩阵（对角）
    'K',                zeros(6,1), ...  增益系数矩阵
    'firstFiltering',   int32(1) ...
 );

%% L2C进行CNAV维特比译码所需的结构体 编码方式：(7,1,2) g1=171,g2=133  此结构体用于C中的卷积码解调，目前不用
% trellis = poly2trellis(7,[171 133]); %生成指定网格图
% STR_vitDec = struct( ...
%     ...'numStates',        64,                  ... 状态数
%     'saveBit',          0,                   ... 由于每次解调需要两个比特，因此收到第一个比特后先暂存。-1表示无。
%     'maxPathLength',    35,                  ... 留存路径最大长度
%     'curPathLength',    0,                   ... 起始阶段需要知道当前路径长度
%     'dist',             zeros(64,1),         ... 保存各条路径的距离
%     'path',             int64(zeros(64,1)), ... 保存各条路径的信息，采用int64类型利于提升c中的处理效率
%     'prevStates',       reshape([0:63,0:63],2,64)', ... 每个状态的前继状态编号
%     'outputs',          trellis.outputs      ... 状态的下一回输出  
% );

%% CN0 estimator structure definition
STR_CN0_Estimator = struct(...
    'CN0EstActive',          0, ...%CN0 estimation enable,1->On; 0->Off.
    'muavg_T',               1,    ...%the time needed for computing a CN0, 1s by default
    'mupool_NMax',           [],   ...% The depth of mu memory pool
    'muk_cnt',               0, ...%mu memory pool counter
    'mu_avg',                0, ...%the computed average mu(NBP/WBP)
    'CN0',                   0, ...%the estimated CN0
    'WideB_Pw_IQ',           zeros(2,1),   ...% wide-band correlators
    'NarrowB_Pw_IQ',         zeros(2,1)    ...% narrow-band correlators
); % 8

STR_CN0_Estimator_plus = struct(...
    'CN0EstActive',          0, ...%CN0 estimation enable,1->On; 0->Off.
    'muavg_T',               1,    ...%the time needed for computing a CN0, 1s by default
    'mupool_NMax',           0,   ...% The depth of mu memory pool
    'muk_cnt',               0, ...%mu memory pool counter
    'mu_avg',                zeros(7,1), ...%the computed average mu(NBP/WBP)
    'CN0',                   zeros(7,1),   ...%the estimated CN0, CA CM CL,目前用到三个，最大支持7码载噪比估计
    'WideB_Pw_IQ',           zeros(14,1),   ...% wide-band correlators
    'NarrowB_Pw_IQ',         zeros(14,1)   ...% narrow-band correlators
); % 8

%% Correlation Bank struct definition
STR_CorrM_Bank = struct(...
    'corrM_Spacing',          2,...%spacing of bank of M Correlators in samples
    'corrM_Num',             [],...%the total number of the correlator bank, eg. M
    'corrM_I_vt',            [],...%mem vectors storing I channels' correlations
    'corrM_Q_vt',            [],...%mem vectors storing Q channels' correlations
    'corrM_Loop_I_vt',       [],...
    'corrM_Loop_Q_vt',       [],...
    'uncancelled_corrM_I_vt',[],...
    'uncancelled_corrM_Q_vt',[],...
    'normRx_I_vt',           [],...% normalized correlation function Rx of the Unit, I channel
    'normRx_Q_vt',           [],...% Q channel
    'normRx_vt',             [],...% I^2 + Q^2
    ...%The following four variables recording the latest correlation shaps
    'corrM_I_vt_Save',       [],...
    'corrM_Q_vt_Save',       [],...
    'uncancelled_corrM_I_vt_Save',   [],...
    'uncancelled_corrM_Q_vt_Save',   []...
);%15

%% lock dectector struct defination
STR_lockDect = struct(...
    'WN',                    0,                 ...Week number counter
    'SOW',                   0,                 ...Second number counter of current subframe beginning in a week
    'Frame_N',               0,                 ...Frame counter, 0~23 for D1, 0~119 for D2
    'SubFrame_N',            0,                 ...Frame counter, 0~4
    'Word_N',                0,                 ...word counter,0~9
    'Bit_N',                 0,                 ...navigation bit counter in a word,0~29       
    'T1ms_N',                0,                 ...PRN period counter in a bit, 0~19 for D1, 0~1 for D2
    'bitInMessage',          0,                 ...
    'CM_in_CL',              0,                 ...
    'codePhase',             0,                 ...
    'carriPhase',            0,                 ...
    'carriDopp',             0,                 ...
    'codeDopp',              0,                 ...
    'cos2phi',               0,                 ...
    'CN0Thres',              0,                 ...
    'cos2phiThres',          0,                 ...
    'lockTime',              0,                 ...
    'sigma',                 0, ...%channel pll discriminator output's variance estimates
    'snr',                   0, ...
    'snrThre',               0, ...
    'sigma_lock',            0, ...
    'sigma_lock_checkT',     0, ...
    'sigma_checkT',          0, ...%[s]
    'sigma_checkNMax',       0, ...
    'sigma_checkTimer',      0, ...
    'sigma_warningCnt',      0, ...
    'sigmaThrelol',          0 ...
    );

%% BDS B1 receiver channel structure definition
STR_CH_B1I = struct(...%
    'CH_STATUS',             'TRACK',...
    'PRNID',                 prn,  ...%
    'navType',               [], ...%type of navigation message ('B1I_D1','B1I_D2')
    'codeTable',             [], ...
    'LO2_CarPhs',            0 + 0.25, ...%0
    'LO2_IF0',               GSAR_CONSTANTS.STR_RECV.IF_B1I, ...%
    'LO2_fd',                0, ...%1200
    'fdPre',                0, ...% 上一次环路反馈后的多普勒
    'fdIndex',                0, ...% 判断用哪一个多普勒
    'LO2_framp',             0, ...%
    'codePhaseErr',             0, ...%
    'LO_CodPhs',             0.0,...%
    'LO_Fcode0',             GSAR_CONSTANTS.STR_B1I.Fcode0, ...%
    'LO_Fcode_fd',           0/763,...
    'Fcode_fdPre',                0, ...% 上一次环路反馈后的扩频码多普勒
    'Tcohn_cnt',             0, ...%
    ...Define information frame format
    'WN',                    0,                 ...Week number counter
    'SOW',                   0,                 ...Second number counter of current subframe beginning in a week
    'Frame_N',               0,                 ...Frame counter, 0~23 for D1, 0~119 for D2
    'SubFrame_N',            0,                 ...Frame counter, 0~4
    'Word_N',                0,                 ...word counter,0~9
    'Bit_N',                 0,                 ...navigation bit counter in a word,0~29       
    'T1ms_N',                0,                 ...PRN period counter in a bit, 0~19 for D1, 0~1 for D2
    ...%Define the track parameters and registers
    'Trk_Count',             0, ...%
    'Tcohn_N',               [], ...%number of 1ms, equivalent to the coherent tracking time
                                ...%recommanded value: 20/n where n is an positive integer
    'Tslot_I',               zeros(3,1), ...%channel I 1ms correlators, [early,prompt,late]
    'Tslot_Q',               zeros(3,1), ...%channel Q 1ms correlators, [early,prompt,late]
    'T_I',                   zeros(3,1), ...%channel I Tms correlators, [early,prompt,late]
    'T_Q',                   zeros(3,1), ...%channel Q Tms correlators, [early,prompt,late]
    'Tcoh_I',                zeros(3,1), ...
    'Tcoh_Q',                zeros(3,1), ...
    'Tcoh_I_prev',           zeros(3,1), ...
    'Tcoh_Q_prev',           zeros(3,1), ...
    'T_pll_I',               zeros(3,1), ...%the I channel Tms correlations that correlates the 
                                         ...%composite signal without cancellatin; it will be 
                                         ...%used only for carrier PLL loop;
    'T_pll_Q',               zeros(3,1), ...
    'Loop_I',                zeros(3,15),...% 按bit位数保存T_I值 / 最多保存20个bit
    'Loop_Q',                zeros(3,15),...% 按bit位数保存T_Q值 / 最多保存20个bit
    'Loop_N',                0,...% Loop_I保存的当前位数
    'PromptIQ_D',            zeros(2,1), ...%delay values of I,Q channels' prompt correlator
                                         ...%[Prompt_I_D, Prompt_Q_D]
    ...%Define the CNR-computing parameters
    'CN0_Estimator',         STR_CN0_Estimator,  ...% B1I channel CN0 estimator structure
    'Samp_Posi',             0, ...%0~N-1
    'lockDect',              STR_lockDect,... % Carrier Phase Lock Dector
    ...%Mems for recording the correlation shape of current Unit
    'CorrM_Bank',            STR_CorrM_Bank, ...
    ...
    'SFNav',                 zeros(10,1), ...
    'SFNav_prev',            zeros(10,1), ...
    'Bit_Inv',               0, ... % 1 means the nav bit should be inverted
    'SF_Complete',           0, ... % Flag whether a subframe is complete
    'Frame_Sync',            'NOT_FOUND', ...
    'state1',                0, ...
    'state2',                0, ...
    ...
    'carrPhaseAccum',        0, ... % Accumulation of carrier phase variation due to doppler frequency
    'ephReady',              0, ... % Flag whether ephemeris is demodulated completely, 1 for yes, 0 for not yet (just in MATLAB)
    'SOW_check',             0, ... % 通过电文解调出的SOW，用于校验正确性
    'SubFrame_check',        0, ...
    'invalidNum',            -1,... % 电文各项参数有效性，-1：未知  0：有效   1、2、3...:连续错误的次数
    'preUnitNum',            -1,... % 上一时刻的unit号
    'bitDetect',             zeros(3,1)  ... % bit1~2 reserved; bit3 is used for cofirming the checking of the correctness of the SOW
);  % 50

STR_CH_B1I.acq = struct(... % Acquisition struct
    'STATUS',                'strong',...  %strong/weak
    'ACQ_STATUS',            0, ...    %0：未捕获   1：冷捕完成    2：精捕完成
    'processing',            0,...      % 正在处理中标志位
    'TimeLen',               0,...    % 捕获所用时长
    'hotWaitTime',           NaN,...    % 热启动有效等待时间
    'hotAcqTime',            0,...      % 热捕获间隔
    'acq_parameters',        [], ...
    'TC',                    0, ...
    'L0Fc0_R',               0, ...
    'IF0',                   0, ...
    'freqSearch',            0, ...
    'freqBin',               0, ...
    'freqOrder',             [], ...
    'sampPerTC_s',           0, ...
    'sampPer2TC_s',          0, ...
    'skipNumberOfCodes',     [], ...
    'accum',                 0, ...
    'acqID',                 0,...      % 判断是否完成捕获
    'resiData',              [],...     % 剩余数据采样点
    'resiN',                 0,...           % resiData的数据长度
    'acqResults',            [],...
    'corrtmp',               [], ...
    'corr',                  [], ...
    'skipNumberOfSamples',   0, ...
    'skipNperCode',          0, ...
    'carriPhase',            0,  ...
    'nhCode',                [], ...
    'nhLength',              0, ...
    'Samp_Posi_dot',         0 ...
);
STR_CH_B1I.acq.acq_parameters = struct(...
    'tcoh',                  0, ...
    'noncoh',                0, ...
    'freqCenter',            0, ...
    'freqBin',               0, ...
    'freqRange',             0, ...
    'thre_stronmode',        0, ...
    'thre_weakmode',         0 ...
    );
STR_CH_B1I.acq.acqResults = struct(...
    'sv',            0,...
    'acqed',         0,...
    'corr',          0,...
    'corrpeak',      0,...
    'freqOrder',     0,...
    'samps',         0,...
    'freqIdx',       0,...
    'codeIdx',       0,...
    'nc',            0,...
    'snr',           0,...
    'doppler',       0,...
    'RcFsratio',     0 ...
);
STR_CH_B1I.bitSync = struct(... % bitSync struct
    'STATUS',                'strong',...  %strong/weak
    'processing',            0,...      % 正在处理中标志位
    'TimeLen',               '0',...    %  bit同步所用时长
    'waitSec',               0, ...%由于没有导航电文翻转引起的BitSync失败，因此等待规定时间重新BitSync
    'waitNum',               0, ...%由于没有导航电文翻转引起的BitSync失败，因此等待规定时间重新BitSync  % 等待采样点数再次经行比特同步
    'waitTimes',             0, ...% 重新bit同步的次数  
    'TC',                    0, ...
    'noncoh',                0, ...
    'nhCode',                [], ...
    'nhLength',              0, ...
    'frange',                0, ...
    'fbin',                  0, ...
    'fnum',                  0, ...
    'freqCenter',            0, ...
    'Fcodesearch',           0, ...
    'sampPerCode',           0, ...
    'skipNumberOfSamples',   0, ...
    'skipNperCode',          0, ...
    'accum',                 0, ...
    'resiData',              [],...
    'resiN',                0,...           % resiData的数据长度
    'carriPhase',            0,  ...
    'Samp_Posi_dot',         0,...
    'offCarri',             [],...
    'bitSyncResults',       [],...
    'bitSyncID',            0,...
    'corr',                  [], ...
    'corrtmp',              [] ...
);
% Define the bitSync results structure
STR_CH_B1I.bitSync.bitSyncResults = struct(...
    'sv',            0,...
    'synced',        0,...
    'nc_corr',       0,...
    'freqIdx',       0,...
    'bitIdx',        0,...
    'doppler',       0 ...
);

if STR_CH_B1I.PRNID > 5
    STR_CH_B1I.navType = 'B1I_D1';
    STR_CH_B1I.Tcohn_N = 10; % D1 signal: maximal integration time 20ms    
else
    STR_CH_B1I.navType = 'B1I_D2';
    STR_CH_B1I.Bit_N = floor(STR_CH_B1I.T1ms_N/GSAR_CONSTANTS.STR_B1I.NT1ms_in_D2);
    STR_CH_B1I.T1ms_N = mod(STR_CH_B1I.T1ms_N, GSAR_CONSTANTS.STR_B1I.NT1ms_in_D2);
    
    STR_CH_B1I.Tcohn_N = 2; % D2 signal: maximal integration time 2ms
end
STR_CH_B1I.Tcohn_cnt = mod(STR_CH_B1I.T1ms_N, STR_CH_B1I.Tcohn_N);

STR_CH_B1I.CN0_Estimator.mupool_NMax = round(STR_CH_B1I.CN0_Estimator.muavg_T*1e3);
STR_CH_B1I.lockDect.sigma_checkNMax = round(STR_CH_B1I.lockDect.sigma_checkT*1e3 / STR_CH_B1I.Tcohn_N);

STR_CH_B1I.CorrM_Bank.corrM_Num = 1 + 2*round( 2 * GSAR_CONSTANTS.STR_RECV.fs / GSAR_CONSTANTS.STR_B1I.Fcode0 / STR_CH_B1I.CorrM_Bank.corrM_Spacing );
STR_CH_B1I.CorrM_Bank.corrM_I_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.corrM_Q_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.corrM_Loop_I_vt = zeros(210, 15); %此处维度必须与C中保持一致
STR_CH_B1I.CorrM_Bank.corrM_Loop_Q_vt = zeros(210, 15); %此处维度必须与C中保持一致
STR_CH_B1I.CorrM_Bank.uncancelled_corrM_I_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.uncancelled_corrM_Q_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.normRx_I_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.normRx_Q_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.normRx_vt = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);

STR_CH_B1I.CorrM_Bank.corrM_I_vt_Save = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.corrM_Q_vt_Save = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.uncancelled_corrM_I_vt_Save = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);
STR_CH_B1I.CorrM_Bank.uncancelled_corrM_Q_vt_Save = zeros(STR_CH_B1I.CorrM_Bank.corrM_Num, 1);

%% GPS L1CA receiver channel structure definition
STR_CH_L1CA = struct(...%
    'CH_STATUS',             ' ',...
    'PRNID',                 prn,  ...%
    'codeTable',             [], ...
    'LO2_CarPhs',            0 , ...%0
    'LO2_IF0',               GSAR_CONSTANTS.STR_RECV.IF_L1CA, ...%
    'LO2_fd',                0, ...%
    'fdPre',                 0, ...% 上一次环路反馈后的多普勒
    'fdIndex',               0, ...% 判断用哪一个多普勒
    'LO2_framp',             0, ...%
    'codePhaseErr',          0, ...%
    'LO_CodPhs',             0, ...%
    'LO_Fcode0',             GSAR_CONSTANTS.STR_L1CA.Fcode0, ...%
    'LO_Fcode_fd',           0, ...
    'Fcode_fdPre',                0, ...% 上一次环路反馈后的扩频码多普勒
    'Tcohn_cnt',             0, ...%
    ...Define information frame format
    'WN',                    0,                 ...Week number counter
    'TOW_6SEC',              0,                 ...Second number counter of current subframe beginning in a week
    'SubFrame_N',            0,                 ...Frame counter, 0~4
    'Word_N',                0,                 ...word counter,0~9
    'Bit_N',                 0,                 ...navigation bit counter in a word,0~29       
    'T1ms_N',                0,                 ...PRN period counter in a bit, 0~19 for D1, 0~1 for D2
    ...%Define the track parameters and registers
    'Trk_Count',             0, ...%
    'Tcohn_N',               10, ...%number of 1ms, equivalent to the coherent tracking time
                                ...%recommanded value: 20/n where n is an positive integer
    'Tslot_I',               zeros(3,1), ...%channel I 1ms correlators, [early,prompt,late]
    'Tslot_Q',               zeros(3,1), ...%channel Q 1ms correlators, [early,prompt,late]
    'T_I',                   zeros(3,1), ...%channel I Tms correlators, [early,prompt,late]
    'T_Q',                   zeros(3,1), ...%channel Q Tms correlators, [early,prompt,late]
    'Tcoh_I',                zeros(3,1), ...
    'Tcoh_Q',                zeros(3,1), ...
    'Tcoh_I_prev',           zeros(3,1), ...
    'Tcoh_Q_prev',           zeros(3,1), ...
    'T_pll_I',               zeros(3,1), ...
    'T_pll_Q',               zeros(3,1), ...
    'Loop_I',                zeros(3,15),...% 按bit位数保存T_I值 / 最多保存20个bit
    'Loop_Q',                zeros(3,15),...% 按bit位数保存T_Q值 / 最多保存20个bit
    'Loop_N',                0,...% Loop_I保存的当前位数
    'PromptIQ_D',            zeros(2,1), ...%delay values of I,Q channels' prompt correlator
                                         ...%[Prompt_I_D, Prompt_Q_D]
    ...%Define the CNR-computing parameters
    'CN0_Estimator',         STR_CN0_Estimator, ...
    'Samp_Posi',             0, ...%0~N-1
    'lockDect',              STR_lockDect, ...%phase lock dector
    'CorrM_Bank',            STR_CorrM_Bank, ...
    ...
    'SFNav',                 zeros(10,1), ...
    'SFNav_prev',            zeros(10,1), ...
    'Bit_Inv',               0, ... % 1 means the nav bit should be inverted
    'SF_Complete',           0, ... % Flag whether a subframe is complete
    'Frame_Sync',            'NOT_FOUND', ...
    'state1',                0, ...
    'state2',                0, ...
    ...
    'carrPhaseAccum',        0, ... % Accumulation of carrier phase variation due to doppler frequency
    'ephReady',              0, ... % Flag whether ephemeris is demodulated completely, 1 for yes, 0 for not yet (just in MATLAB)
    'last_twobits',          [],... % the last two bits of previous code
    'SOW_check',             0, ... % 通过电文解调出的SOW，用于校验正确性
    'SubFrame_check',        0, ...
    'invalidNum',            -1,... % 电文各项参数有效性，-1：未知  0：有效   1、2、3...:连续错误的次数
    'preUnitNum',            -1,... % 上一时刻的unit号
    'bitDetect',             zeros(3,1)  ... % bit1~2 reserved; bit3 is used for cofirming the checking of the correctness of the SOW
);  % 46


STR_CH_L1CA.acq = struct(... % Acquisition struct
    'STATUS',                'strong',...  %strong/weak
    'ACQ_STATUS',            0, ...    冷捕获时的捕获等级 -- 0:未捕获， 1：CA码冷捕获完成  2：精捕获完成  3：CM码捕获完成  4：CL码捕获完成
    'acqID',                 0,...      % 判断是否完成捕获
    'processing',            -1,...      % 正在处理中标志位
    'TimeLen',               0,...    % 捕获所用时长
    'hotWaitTime',           NaN,...    % 热启动有效等待时间
    'hotAcqTime',            0,...      % 热捕获间隔
    'TC',                    0, ...
    'L0Fc0_R',               0, ...
    'IF0',                   0, ...
    'freqSearch',            0, ...
    'freqBin',               0, ...
    'freqOrder',             [], ...
    'sampPerTC_s',           0, ...
    'sampPer2TC_s',          0, ...
    'skipNumberOfCodes',     [], ...
    'skipNumberOfSamples',   0, ...
    'skipNperCode',          0, ...
    'accum',                 0, ...
    'corrtmp',               [], ...
    'corr',                  [], ...
    'corrtmp_fine',          [], ...  
    'corr_fine',             [], ...  
    'resiData',              [],...   %剩余数据采样点
    'resiN',                 0, ...   %resiData的数据长度
    'carriPhase',            0, ...
    'carriPhase_vt',         [], ...  
    'Samp_Posi_dot',         0, ...    
    'acq_parameters',        [],...
    'acqResults',            [], ...
    ...acq varibles for L2C
    'CM_corrtmp',           [], ... 1ms积分结果
    'CM_corr',              [], ... 总积分结果
    'CM_peak',               0, ... CM码捕获峰值，作为捕获CL时的门限参考
    'CL_corrtmp',           [], ... 1ms积分结果
    'CL_corr',              [], ... 总积分结果
    'CL_search',            [] ... 捕获CL码时的搜索范围，包含0,1,2，...，74的数组
);
STR_CH_L1CA.acq.acq_parameters = struct(...
    'tcoh',                  0, ...
    'noncoh',                0, ...
    'freqCenter',            0, ...
    'freqBin',               0, ...
    'freqRange',             0, ...
    'thre_stronmode',        0, ...
    'thre_weakmode',         0 ...
    );
STR_CH_L1CA.acq.acqResults = struct(...         %define the acquisition results structure
    'sv',            0,...
    'acqed',         0,...
    'corr',          0,...
    'corrpeak',      0,...
    'freqOrder',     0,...
    'samps',         0,...
    'freqIdx',       0,...
    'codeIdx',       0,...
    'nc',            0,...
    'snr',           0,...
    'doppler',       0,...
    'RcFsratio',     0 ...
);
STR_CH_L1CA.bitSync = struct(... % bitSync struct
    'STATUS',                'strong',...  %strong/weak
    'processing',            0,...      % 正在处理中标志位
    'TimeLen',               '0',...    % bit同步所用时长
    'waitSec',               0, ...%由于没有导航电文翻转引起的BitSync失败，因此等待规定时间重新BitSync
    'waitNum',               0, ...%由于没有导航电文翻转引起的BitSync失败，因此等待规定时间重新BitSync  % 等待采样点数再次经行比特同步
    'waitTimes',             0, ...% 重新bit同步的次数   
    'TC',                    0, ...
    'noncoh',                0, ...
    'nhCode',                [], ...
    'nhLength',              0, ...
    'frange',                0, ...
    'fbin',                  0, ...
    'fnum',                  0, ...
    'freqCenter',            0, ...
    'Fcodesearch',           0, ...
    'sampPerCode',           0, ...
    'skipNumberOfSamples',   0, ...
    'skipNperCode',          0, ...
    'accum',                 0, ...
    'resiData',              [],...         % 剩余未处理的数据量
    'resiN',                 0,...           % resiData的数据长度
    'carriPhase',            0,  ...
    'Samp_Posi_dot',         0,...
    'offCarri',             [],...
    'bitSyncResults',       [],...
    'bitSyncID',             0,...
    'corr',                 [], ...
    'corrtmp',              [] ...
);
STR_CH_L1CA.bitSync.bitSyncResults = struct(...
    'sv',            0,...
    'synced',        0,...
    'nc_corr',       0,...
    'freqIdx',       0,...
    'bitIdx',        0,...
    'doppler',       0 ...
);
STR_CH_L1CA.Tcohn_cnt = mod(STR_CH_L1CA.T1ms_N, STR_CH_L1CA.Tcohn_N);

STR_CH_L1CA.CN0_Estimator.mupool_NMax = round(STR_CH_L1CA.CN0_Estimator.muavg_T*1e3);
%STR_CH_L1CA.lockDect.sigma_checkNMax = round(STR_CH_L1CA.lockDect.sigma_checkT*1e3 / STR_CH_L1CA.Tcohn_N);

STR_CH_L1CA.CorrM_Bank.corrM_Num = 5 + 2*round( 2 * GSAR_CONSTANTS.STR_RECV.fs / GSAR_CONSTANTS.STR_L1CA.Fcode0 / STR_CH_L1CA.CorrM_Bank.corrM_Spacing );
STR_CH_L1CA.CorrM_Bank.corrM_I_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.corrM_Q_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.corrM_Loop_I_vt = zeros(210, 15); %此处维度必须与C中保持一致
STR_CH_L1CA.CorrM_Bank.corrM_Loop_Q_vt = zeros(210, 15); %此处维度必须与C中保持一致
STR_CH_L1CA.CorrM_Bank.uncancelled_corrM_I_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.uncancelled_corrM_Q_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.normRx_I_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.normRx_Q_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.normRx_vt = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);

STR_CH_L1CA.CorrM_Bank.corrM_I_vt_Save = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.corrM_Q_vt_Save = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.uncancelled_corrM_I_vt_Save = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);
STR_CH_L1CA.CorrM_Bank.uncancelled_corrM_Q_vt_Save = zeros(STR_CH_L1CA.CorrM_Bank.corrM_Num, 1);

%% GPS L1CA & L2C receiver channel structure definition 
STR_CH_L1CA_L2C = struct(...%
    'CH_STATUS',             ' ',...
    'PRNID',                 prn, ...
    'Samp_Posi',             0, ...
    ...频率相关  
    'LO_CodPhs',             0, ... 本地码相位
    'LO_CodPhs_L2',          0, ... 
    'LO2_CarPhs',            0, ... 本地载波相位
    'LO2_CarPhs_L2',         0, ... 
    'LO2_fd',                0, ... 多普勒
    'LO2_fd_L2',             0, ...
    'LO2_framp',             0, ... 多普勒变化率
    'LO2_framp_L2',          0, ...
    'LO_Fcode0',             GSAR_CONSTANTS.STR_L1CA.Fcode0,  ...  原始码率
    'LO_Fcode_fd',           0, ... 码多普勒
    'LO2_IF0',               GSAR_CONSTANTS.STR_RECV.IF_L1CA, ... 中频
    'LO2_IF0_L2',            GSAR_CONSTANTS.STR_RECV.IF_L2C,  ... 
    ...时间相关
    'WN',                    0,          ...Week number counter
    'TOW_6SEC',              0,          ...Second number counter of current subframe beginning in a week
    'SubFrame_N',            0,          ...Frame counter, 0~4
    'Word_N',                0,          ...word counter,0~9
    'Bit_N',                 0,          ...navigation bit counter in a word,0~29       
    'T1ms_N',                0,          ...PRN period counter in a bit, 0~19 for D1, 0~1 for D2
    'bitInMessage',          0,          ...比特在L2电文message中的位置，0~599 ？？？
    'CM_in_CL',              0,          ... CM码在CL码中的位置0~74
    'CL_time',               0,          ... 0~1.5s
    ...积分相关
    'trk_mode',              [], ... 跟踪模式
    'Trk_Count',             0, ... 1ms跟踪的总次数
    'Tcohn_N',               0, ... 相干积分时间（ms)
    'Tcohn_cnt',             0, ... 已进行的相干积分毫秒数，每次相干积分结束后清零 
    'Tslot_I',               zeros(3,1), ...%channel I 1ms correlators, [early,prompt,late]
    'Tslot_Q',               zeros(3,1), ...%channel Q 1ms correlators, [early,prompt,late]
    'T_I',                   zeros(3,1), ...%channel I Tms correlators, [early,prompt,late]
    'T_Q',                   zeros(3,1), ...%channel Q Tms correlators, [early,prompt,late]
    'Tslot_I_CM',            zeros(3,1), ...
    'Tslot_Q_CM',            zeros(3,1), ...
    'T_I_CM',                zeros(3,1), ...
    'T_Q_CM',                zeros(3,1), ...
    'Tslot_I_CL',            zeros(3,1), ...
    'Tslot_Q_CL',            zeros(3,1), ...
    'T_I_CL',                zeros(3,1), ...
    'T_Q_CL',                zeros(3,1), ...
    'Loop_I',                zeros(3,15),... 暂不使用 【CUDA】：保存每一ms的CA码I路积分
    'Loop_Q',                zeros(3,15),... 暂不使用 【CUDA】：保存每一ms的CA码Q路积分
    'Loop_N',                0,          ... 暂不使用 【CUDA】：保存的毫秒数
    'PromptIQ_D',            zeros(2,1), ... 暂不使用 【锁频环】：上一时刻的CA码I，Q路积分
    'PromptIQ_D_CM',         zeros(2,1), ... 暂不使用 【锁频环】：上一时刻的CM码I，Q路积分
    'PromptIQ_D_CL',         zeros(2,1), ... 暂不使用 【锁频环】：上一时刻的CL码I，Q路积分
    'T_pll_I',               zeros(3,1), ... 暂不使用 【多径抑制】前的CA码I路积分
    'T_pll_Q',               zeros(3,1), ... 暂不使用 【多径抑制】前的CA码Q路积分
    'codePhaseErr',          0, ...          暂不使用 【多径抑制】前后的码相位差异
    'carrPhaseAccum',        0, ...         【定位】Accumulation of carrier phase variation due to doppler frequency
     ...解调相关
    'Frame_Sync',            'NOT_FOUND', ...
    'Frame_Sync_CNAV',       'NOT_FOUND', ...
    'SFNav',                 uint32(zeros(10,1)), ... 正在解调的子帧
    'SFNav_prev',            uint32(zeros(10,1)), ... 完整子帧
    'Msg_CNAV',              uint32(zeros(20,1)), ... 正在解调的Massage信息（未解卷积码）
    'Msg_CNAV_prev',         uint32(zeros(20,1)), ... 解调完成的Massage信息（未解卷积码）
    'Bit_Inv',               0, ... % 1 means the nav bit should be inverted
    'Bit_Inv_CNAV',          0, ... 
    'SF_Complete',           0, ... % Flag whether a subframe is complete    
    'Msg_Complete',          0, ...
    'preamble_NAV_save',     uint32(0), ... 保存CL起始后的第1~8个比特做帧头匹配
    'preamble_CNAV_save',    uint32(0), ... 保存CL起始后的第13~28个比特做帧头匹配
    'NAV_sync_on',           0,         ... 启动帧头匹配的标志
    'CNAV_sync_on',          0,         ...
    'lastSixBits',           uint32(0), ...
    ...校验相关
    'SOW_check',             0, ... % 通过电文解调出的SOW，用于校验正确性
    'SubFrame_check',        0, ...
    'preUnitNum',            -1,... % 上一时刻的unit号
    'invalidNum',            -1,... % 电文各项参数有效性，-1：未知  0：有效   1、2、3...:连续错误的次数
    'bitDetect',             zeros(3,1),  ... bit1~2 reserved; bit3 is used for cofirming the checking of the correctness of the SOW
    ...定义子结构体
    ...'vitDec',                STR_vitDec, ...  维特比译码所需结构体,目前译码在MATLAB中完成，结构体用不上
    'acq',                   STR_CH_L1CA.acq, ...
    'CN0_Estimator',         STR_CN0_Estimator_plus, ...
    'lockDect',              STR_lockDect, ...%phase lock dector
    'CorrM_Bank',            STR_CorrM_Bank,    ...
    'KalPreFilt_L1L2',       STR_KalPreFilt_plus, ...  双频联合所用的Kalman结构体
    ... 以下为双频单独跟踪时用于L2频点的结构体
    'PLL_L2',                STR_PLL, ...
    'DLL_L2',                STR_DLL ...
);  %

%% Define the CADLL Control Structure
STR_CAD.CADLL_MODE = 'CADLL';       % CADLL/CONVENTION
STR_CAD.CAD_STATUS = 'CAD_TRACK';   % CAD_TRACK/NEWMP_LOOKFOR/TRANSIENT
% Steady tracking status between two MP detecting operations, equivalently CadCnt*1e-3 seconds
STR_CAD.CadCnt        = 0;
STR_CAD.MONI_TYPE     = 'MONI_ALLON';  % MONI_CODPHS_DIFF/MONI_A_STD/MONI_CN0/MONI_SNR/MONI_A_AVG/MONI_ALLON
STR_CAD.MONI_TYPE_TR  = 'MONI_ALLON';  % MONI_CODPHS_DIFF/MONI_A_STD/MONI_CN0/MONI_SNR/MONI_A_AVG/MONI_ALLON
% Define the supported maximum number of units in cadll algorithm, CadUnitMax<=10;
STR_CAD.CadUnitMax = 3;
STR_CAD.CadUnit_N  = 1;             % define current number of units;
% Initial code phase delay in chips with respect to the first unit when inserting the second unit;
STR_CAD.CadU2_CodeIni   = 0.1;%0.8;
% The initial code phase delay in chips with respect the unit before when inserting the third and
% more unit;
STR_CAD.CadUin_CodeIni  = 0.1;   %B1I: 0.25; GPS_CA: 0.075
% The initial amplitude of the inserted unit with repsect to the unit before;
STR_CAD.CadUin_AIni     = 0.0;
% The initial carrier phase of the inserted unit with repsect to the unit before, [cycles];
STR_CAD.CadUin_ThetaIni = 0.5;

STR_CAD.MonitoringTime = 1; % monitoring time before making a decision;
% Equivalent maximum number that Monitor counter counts to, the counter counts at a rate of 1kHz
STR_CAD.MoniNMax = round(STR_CAD.MonitoringTime/1e-3);
STR_CAD.Moni_N   = 0;    % Monitor counter, counting from 0~MoniNMax-1, counting at a rate of 1kHz

% The mandatory code phase lag by force between two adjacent units,[chips]
STR_CAD.CodPhsLagThre1 = 0.05;    %B1I: 0.05; GPS_CA: 0.025
% The code phase lag threshold of two adjacent units; the latter unit will be shut down if its code
% phase delay is less than the threshold 
STR_CAD.CodPhsLagThre2 = 0.09;     %B1I: 0.1; GPS_CA: 0.05
% The least code phase lag between two adjacent units between that a trial unit can be inserted;
STR_CAD.CodPhsLag_Insrt_Thre3 = 0.2;  %B1I: 0.2; GPS_CA: 0.1
STR_CAD.AThreLow1    = 0.12;      % the lowest amplitude1 permitted;
STR_CAD.AThreLow2    = 0.1;     % the lowest amplitude2 permitted;
STR_CAD.AThreLow3    = 0.07;
STR_CAD.ADevThre     = 2.5;        % permitted maximum std deviation ratio of estimated amplitude to noise's;
STR_CAD.CN0Thre      = 23;       % permitted minimum CN0 (estimated)
STR_CAD.SNRThre1     = -2;       % permitted minimum SNR1 (estimated)
STR_CAD.SNRThre2     = -4;      % permitted minimum SNR2 (estimated)
STR_CAD.SNRThre3     = -6;
STR_CAD.SNRThre4     = -8;
% Unit0's SNR, synchronized with ALL.SNR. It is used for control CADLL
% controller weather to start or shutdown the CADLL detection.
STR_CAD.Unit0SNR_Det = 0;
% STR_CAD.ThetaDevThre = 15;       % permitted maximum std deviation of estimated carrier phase bias,[deg];

% Define thresholds for loss of lock detection
STR_CAD.SNRThrelol   = 5; % [dB], TODO,unused currently
STR_CAD.sigmaThrelol = 0.015;
STR_CAD.LossThre     = 2; % Loss of lock level

%***** Define some registers computing the tracking parameters of each unit *****
% Computing the code phase lag between two adjacent units
STR_CAD.CodPhsDiff_Avg = zeros(STR_CAD.CadUnitMax,1); % zeros(STR_CAD.CadUnitMax-1,1) ??? the last element is empty
STR_CAD.CodPhsDiff_Avg_prev = zeros(STR_CAD.CadUnitMax,1); %Store the previous CodPhsDiff_Avg
% Computing the normalized average amplitude of a signal component during one monitoring time
STR_CAD.A_Avg = zeros(STR_CAD.CadUnitMax,1);
% Compute the normalized amplitude stadard deviation of a signal component during one monitoring
% time.
STR_CAD.A_Std = zeros(STR_CAD.CadUnitMax,1);
% Allocate the tang registers for counting the number of errors of each unit
STR_CAD.UnitErrTang_N = int32(zeros(STR_CAD.CadUnitMax,1));

%***** Define some parameters regarding detecting a new MP *****
% The checking point of a new multipath in the CADLL chain, also called the inserted point. The new 
% unit will be inserted between InsrtNo~InsrtNo+1, so InsrtNo will be 0~CadUnit_N-1.
STR_CAD.InsrtNo = 0;
STR_CAD.CadCH_L1CA_Tr = STR_CH_L1CA; % Trail CH for L1CA signal in cadll detecting a new multipath
STR_CAD.CadCH_L2C_Tr = STR_CH_L1CA_L2C; % Trail CH for L2C signal in cadll detecting a new multipath
STR_CAD.CadCH_B1I_Tr = STR_CH_B1I; % Trail CH for B1I signal in cadll detecting a new multipath
STR_CAD.CadDLL_Tr    = STR_DLL;    % Trail CH's DLL structure
STR_CAD.CadALL_Tr    = STR_ALL;    % Trail CH's ALL structure
% The time for estimating the new multipath's CNR,[s]
STR_CAD.TrConfirmT     = 1;
% Equivalent number of 1ms for estimating the new multipath's CNR,[s]
STR_CAD.TrConfirm_NMAX = round(STR_CAD.TrConfirmT/1e-3);
% CN0 threshold for detecting a new multipath signal, one below that is deemed as nuisances.
STR_CAD.TrCN0Thre      = 23;    %16;
STR_CAD.TrSNRThre      = -8;    %-13;
STR_CAD.TrAmpThre      = 0.08;     %0.07; % Divide amplitude of trail ch by amplitude of LOS

STR_CAD.TrCodphsDiff_Avg = 0;
STR_CAD.TrChkSum_Errcode = uint32(0);  % CH_Tr checksum error code
STR_CAD.Codfreq_Proj_Tr_ErrTang = 0;
%***** Define the time of CAD_TRACK status and TRASIENT status *****
STR_CAD.CadLoopTime       = 1; % Stably tracking time between two MP detecting operations,[s]
STR_CAD.CadLoop_NMAX      = round(STR_CAD.CadLoopTime/1e-3); %1000
STR_CAD.CadTransientTime  = 0.5; % Transient time
STR_CAD.CadTransient_NMAX = round(STR_CAD.CadTransientTime/1e-3); %500

% EOF of "Define STR_CAD struct", 45 components


%% Finish the resultant initializations
switch STR_CAD.CAD_STATUS
    case 'CAD_TRACK'
        STR_CAD.CadCnt = STR_CAD.CadLoop_NMAX;%Debugging
    case 'NEWMP_LOOKFOR'
        STR_CAD.CadCnt = STR_CAD.TrConfirm_NMAX;
    case 'TRANSIENT'
        STR_CAD.CadCnt = STR_CAD.CadTransient_NMAX;
end

STR_CH_noise = struct(...
    'Codphs_ns',               0,             ...% noise channle's code phase
    'Tslot_ns_IQ',             zeros(2,1),    ...% 1ms correlations of noise channel, I,Q channels
    'T_ns_IQ',                 zeros(4,1),    ...% Tms correlations of noise channel, I,Q channels
    'Avg_ns_IQ',               zeros(2,1),    ...% average over 1s, I,Q channels
    'Sq_ns_IQ',                zeros(2,1),    ...% average squares over 1s, I,Q channels
    'ns_Std',                  0,             ...% noise channel's std
    'NsCnt',                   0,             ...% noise channle counter
    'NormFactor',              0              ...% normalizing factor
);% 7


%% Define the Receive Structure
channels = struct(...
    'SYST',                  '',    ...
    'STATUS',                '',    ...
    'IQForm',                GSAR_CONSTANTS.STR_RECV.IQForm, ...% Complex/Real Input data format
    'CH_L1CA',               STR_CH_L1CA, ...%
    'CH_L1CA_L2C',           STR_CH_L1CA_L2C, ...%
    'CH_B1I',                STR_CH_B1I, ...%
    'CH_B1I_B2I',            [ ], ...
    'PLL',                   STR_PLL, ...%
    'DLL',                   STR_DLL, ...%
    'ALL',                   STR_ALL, ...% 
    'STR_CAD',               STR_CAD, ...
    'KalPreFilt',            STR_KalPreFilt,...
    'CH_ns',                 STR_CH_noise,  ...% Definition of noise channel
    'bpSampling_OddFold',    GSAR_CONSTANTS.STR_RECV.bpSampling_OddFold ...
);
