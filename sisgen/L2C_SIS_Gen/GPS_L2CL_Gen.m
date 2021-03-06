
%  This functin will generate GPS L2CL code

function GPS_L2CL = GPS_L2CL_Gen(PRNID)
%INPUT:    
% PRNID         - the ID number of the GPS L2CL code
%OUTPUT�� 
% GPS_L2CL      - the PRN code of GPS L2CL


GPS_L2CL_Ini = GPS_L2CL_Ini_Table( );  % the statement of calling the function

G = GPS_L2CL_Ini(PRNID,:);  % the initialization of generation

L = 767250;   % the length of GPS_L2CL PRN code

GPS_L2CL = ones(1,L);  % storing GPS_L2CL PRN code

for i = 1:L-1

    output = G(27);  % generate the GPS_L2CL PRN code   
    
    G(27) = G(26);
    G(26) = G(25);
    G(25) = G(24)*output;
    G(24) = G(23)*output;
    G(23) = G(22)*output;
    G(22) = G(21)*output;
    G(21) = G(20);
    G(20) = G(19);
    G(19) = G(18)*output;
    G(18) = G(17);
    G(17) = G(16)*output;
    G(16) = G(15);
    G(15) = G(14)*output;
    G(14) = G(13);
    G(13) = G(12);
    G(12) = G(11)*output;
    G(11) = G(10);
    G(10) = G(9);
    G(9)  = G(8)*output;
    G(8)  = G(7);
    G(7)  = G(6)*output;
    G(6)  = G(5);
    G(5)  = G(4);
    G(4)  = G(3)*output;
    G(3)  = G(2);
    G(2)  = G(1);
    G(1)  = output; 
    
    GPS_L2CL(i) = output;
end

GPS_L2CL(L) = G(27);

% G






