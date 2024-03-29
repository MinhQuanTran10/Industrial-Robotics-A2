clear
close all

r = DobotMagicianwithGripper;
hold on
h = PlaceObject('Carrot.ply',[0,-0.276,0.02]);

% desired joint state at final position
qPick = [-90 45 35 -35 -90]*pi/180;

T1 = r.model.fkine(r.model.getpos);
T2 = r.model.fkine(qPick);

% create a simple straight line trajectory
steps = 120;
T = trinterp(T1,T2,linspace(0,1,steps));

% safe step of time for not exceed each joint's max speed
timestep = 0.05;

% random collision trigger:
checkCollision = randi([1,steps+10],1,1);

%% track the trajectory by RRMC
for i = 1:steps-1
    qCurrent = r.model.getpos;
    currentPose = r.model.fkine(qCurrent);

    % trace the end-effector
    plot3(currentPose(1,4),currentPose(2,4),currentPose(3,4),'r.');

    % check collision and try to avoid
    if i == checkCollision
        if i <= steps/2
            disp(['Collision detected at step ',num2str(i),'. Try to avoid!']);
            stepLeft = steps - i;

            % trajectory to lift the arm vertically
            zLift = 0.15;
            T_Lift = transl(0,0,zLift)*currentPose;
            step4Lift = floor(stepLeft/4);
            T(:,:,i:i+step4Lift) = trinterp(currentPose,T_Lift,linspace(0,1,step4Lift+1));

            % trajectory to move the arm horizontally in x-direction
            xMove = 0.05;
            T_xMove = transl(-xMove,0,0)*T_Lift;
            step4Move = floor((stepLeft - step4Lift)/4);
            T(:,:,i+step4Lift: i+step4Lift+step4Move) = trinterp(T_Lift,T_xMove,linspace(0,1,step4Move+1));

            % trajectory to move the arm to the destination
            T(:,:,i+step4Lift+step4Move: steps) = trinterp(T_xMove,T2, linspace(0,1,stepLeft-step4Lift-step4Move +1));
        else
            disp('Cannot find way to avoid this collision. Stop the robot!');
            break;
        end
    end

    % spatial velocity
    u = (transl(T(:,:,i+1)) - transl(T(:,:,i)))/timestep;
    omega = (tr2rpy(T(:,:,i+1)) - tr2rpy(T(:,:,i)))/timestep;

    % joint velocity
    qd = pinv(r.model.jacob0(qCurrent)) * [u; omega'];

    % next position
    qNext = qCurrent + qd'*timestep;

    % check the validity of the next joint state:
    checkLimit = CheckJointLimit(r.model,qNext);
    if  checkLimit <= r.model.n
        disp(['Step ',num2str(i),'. Warning: exceed joint limit at joint ', num2str(checkLimit), ...
            '. A patch using IK solution is applied!']);

        % replace the invalid 'qNext' by an IK solution:
        poseNext = r.model.fkine(qNext);
        qNext = r.model.ikcon(poseNext,r.model.getpos);
    end

    % move the robot
    r.MoveRobot(qNext);

    % try to correct the final position:
    if i == steps -1
        currentPose = r.model.fkine(r.model.getpos);
        % current error between the desired pose and the current pose
        error_displacement = norm(T2(1:3,4) - currentPose(1:3,4));

        % try to correct the position by jtraj if the error  > 5mm
        if error_displacement > 0.005
            disp(['Last step error is ',num2str(1000*error_displacement),'mm > 5mm. A jtraj correction is applied!']);
            qCorrect = jtraj(r.model.getpos,qPick,steps);
            r.MoveRobot(qCorrect);
        end

        % display the final error
        currentPose = r.model.fkine(r.model.getpos);
        error_displacement = norm(T2(1:3,4) - currentPose(1:3,4));
        disp(['Current error is ',num2str(1000* error_displacement),'mm.']);
    end
end




