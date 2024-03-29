clear
% close all

carrot = Veggie('Carrot.ply',transl(0,-0.276,0.02),[255,128,0]/255);
robot1 = DobotMagicianwithGripper;

robot2 = Dorna2Robot;
robot2.model.base = transl([0.77 0 0]) * trotz(pi);
robot2.MoveRobot(robot2.model.getpos);

%%  Set up for Dobot
view([34.58 27.20])

pause()

xlim([-0.65 3.56])
ylim([-2.14 1.35])
zlim([-0.05 2.36])
view([17.70 24.49])

% desired joint state at final position
qPick_dobot = [-90 45 35 -35 -90]*pi/180;

% required initial and final pose
poseCurrent_dobot = robot1.model.fkine(robot1.model.getpos);
poseFinal_dobot = robot1.model.fkine(qPick_dobot);

pointCurrent_dobot = poseCurrent_dobot(1:3,4);
pointFinal_dobot = poseFinal_dobot(1:3,4);
error_displacement_dobot = norm(pointFinal_dobot - pointCurrent_dobot);

% number of desired steps from initial position to final position
steps = 50;

% safe step of time for not exceed each joint's max speed
timestep = 0.05;

% manipulability threshold
mani_threshold = 0.0044;

% max damping coefficient 
damping_coefficient_MAX = 0.05;


% random collision trigger:
%checkCollision = randi([1,steps+10],1,1);
checkCollision = 24;

count = 0;
pause();

%% Dobot tracks the trajectory by RRMC
% the closer the obstacle to the target, the less accurate of the
% avoidance

while error_displacement_dobot > 0.003

    % trace the end-effector
    % plot3(poseCurrent(1,4),poseCurrent(2,4),poseCurrent(3,4),'r.');

    % check collision and try to avoid
    if count == checkCollision
        disp(['Collision detected at step ',num2str(count)]);

        % try to avoid that collision if possible
        if (count/steps) < 3/5
            % lift the arm
            zLift = 0.2;
            T_Lift = transl(0,0,zLift)*poseCurrent_dobot;
            RMRCMotion(robot1,T_Lift,30);

            % move in plane xy
            xMove = 0.08;
            yMove = 0.08;
            T_xyMove = transl(-xMove,-yMove,0)*T_Lift;
            RMRCMotion(robot1,T_xyMove,30);
        else
            disp('Cannot find way to avoid this collision. Stop the robot!');
            break;
        end
    end

    % current joint state 
    qCurrent = robot1.model.getpos;
    
    % current manipulability and Jacobian
    mani =  robot1.model.maniplty(qCurrent);
    J = robot1.model.jacob0(qCurrent);
 
    % retrieve the current pose
    poseCurrent_dobot = robot1.model.fkine(qCurrent);

    % current difference to the final position
    distanceDiff = transl(poseFinal_dobot) - transl(poseCurrent_dobot);
    angleDiff = tr2rpy(poseFinal_dobot) - tr2rpy(poseCurrent_dobot);

    % desired spatial velocity
    u = (distanceDiff/(steps-count))/timestep;
    omega = (angleDiff/(steps-count))/timestep;

    % reduce singularity if exists
    if mani < mani_threshold
        damping_coefficient = (1-(mani/manithreshold)^2)/damping_coefficient_MAX;
        J_DLS = J'/(J*J'+ damping_coefficient*eye(6));    % damped least square Jacobian
        
        % joint velocity
        qd = J_DLS * [u; omega'];
    else
        % joint velocity
        qd = pinv(J) * [u; omega'];
    end

    % next position
    qNext = qCurrent + qd'*timestep;

    % check the validity of 'qNext':
    checkLimit = CheckJointLimit(robot1.model,qNext);
    if  checkLimit <= robot1.model.n
        disp(['Step ',num2str(count),'. Warning: exceed joint limit at joint ', num2str(checkLimit), ...
            '. A patch using IK solution is applied!']);

        % replace the invalid 'qNext' by an IK solution:
        poseNext = robot1.model.fkine(qNext);
        qNext = robot1.model.ikcon(poseNext,robot1.model.getpos);
    end

    % move robot
    robot1.MoveRobot(qNext);

    % retrieve the current pose
    poseCurrent_dobot = robot1.model.fkine(robot1.model.getpos);
    pointCurrent_dobot = poseCurrent_dobot(1:3,4);
    error_displacement_dobot = norm(pointFinal_dobot - pointCurrent_dobot);

    count = count+1;
end

disp(['Current error is ',num2str(1000* error_displacement_dobot),'mm.']);

posePick_mid_dobot = robot1.model.fkine(robot1.model.getpos);

%% Lower the arm to pick the object 

% Gripped object's transform seen by the Dobot's end-effector
objectTr_Dobot = transl(0,0,-0.040);

if error_displacement_dobot <= 0.003
    posePick = transl(0,0,-0.04)*posePick_mid_dobot;
    
    robot1.MoveGripper(25);
    RMRCMotion(robot1,posePick,20);
    robot1.MoveGripper(24);

%% Bring it to the chopping position
    RMRCMotion(robot1,posePick_mid_dobot,20,carrot,objectTr_Dobot);
    RMRCMotion(robot1,robot1.model.fkine(robot1.defaultJoint),50,carrot,objectTr_Dobot);
end

%% Replace the carrot with carrot pieces

carrotPose = carrot.pose;
delete(carrot.mesh_h);
delete(carrot);
hold on

for i = 1:6
    carrotPiece(i) = Veggie(['CarrotPiece_',num2str(i),'.ply'],carrotPose);
end

%% Dorna 2 joins

%> Gripped object's transform (no orientation) seen by the Dorna's end-effector
objectTr_Dorna = transl(0.228,0,0.155)*rpy2tr(-2*pi,-pi/2,2*pi);

pose_First_Dorna = nan(4,4,5);
pose_Second_Dorna = nan(4,4,5);

q_First_Dorna =   [0,-61,82,-20,0] * pi/180;

% top right corner
pose_Default_Dorna = robot2.model.fkine(robot2.defaultJoint);

% top left corner
pose_First_Dorna(:,:,1) = robot2.model.fkine(q_First_Dorna);

% bottom left corner
pose_Second_Dorna(:,:,1) = transl([0 0 -0.04]) * pose_First_Dorna(:,:,1);

% bottom right corner
pose_Third_Dorna = transl([0 0 -0.05]) * pose_Default_Dorna;

% thickness of each slice
slice = 0.017;

pause()
for i = 1:4
    pose_First_Dorna(:,:,i+1) = transl(-slice,0,0)*pose_First_Dorna(:,:,i);
    pose_Second_Dorna(:,:,i+1) = transl(-slice,0,0)*pose_Second_Dorna(:,:,i);
end

% cutting operation
for i =1:5
    % reach the top left
    RMRCMotion(robot2,pose_First_Dorna(:,:,i),40);

    % chop down (bottom left)
    RMRCMotion(robot2,pose_Second_Dorna(:,:,i),40);

    % adjust the transform of each veggie piece
    adjustTr = transl(0,0,-(slice+0.005)*(i-1))*objectTr_Dorna;
    % push the veggie piece towards the bowl (bottom right)
    RMRCMotion(robot2,pose_Third_Dorna,50,carrotPiece(i),adjustTr);
    
    % veggie piece falls inside the bow
    steps_fall = 20;
    T = RandominBowl(carrotPiece(i).pose,steps_fall);

    for j =1:steps_fall
        carrotPiece(i).Update(T(:,:,j));
        drawnow();
    end
    
    % go back initial position(top right)
    RMRCMotion(robot2,pose_Default_Dorna,40);
end


