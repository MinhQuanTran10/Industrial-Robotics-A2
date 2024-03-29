%% function for straight line RMRC motion

function RMRCMotion(robot,poseFinal,steps,object,objectTr)
    % robot: robot object, which has MoveRobot method
    % qFinal: final joint state of the robot
    % steps : desired steps for the trajectory from current -> final Pose
    % object: gripped object for robot's gripper of the class 'Veggie'
    % objectTr: object's transform seen by the robot

    % safe step of time for not exceed each joint's max speed
    timestep = 0.05;
    
    % manipulability threshold
    mani_threshold = 0.0044;

    % max damping coefficient 
    damping_coefficient_MAX = 0.05;

    % get initial pose
    poseCurrent = robot.model.fkine(robot.model.getpos);
    
    pointCurrent = poseCurrent(1:3,4);
    pointFinal = poseFinal(1:3,4);
    error_displacement = norm(pointFinal - pointCurrent);
    
    objectExist = false;

    if exist('object','var') 
        objectExist = true;
        if ~exist('objectTr','var')
            objectTr = eye(4);
        end
    end
    
    count = 0;
    
    %% track the trajectory by RRMC
    while error_displacement > 0.003
        % trace the end-effector
        % plot3(poseCurrent(1,4),poseCurrent(2,4),poseCurrent(3,4),'r.');
        
        % current joint state 
        qCurrent = robot.model.getpos;
        
        % manipulability and Jacobian
        mani =  robot.model.maniplty(qCurrent);
        J = robot.model.jacob0(qCurrent);
    
        % current difference to the final position
        distanceDiff = transl(poseFinal) - transl(poseCurrent);
        angleDiff = tr2rpy(poseFinal) - tr2rpy(poseCurrent);
        
        % disallow the angular difference > pi:
        for i =1:3
            if abs(angleDiff(i)) >= 3.14
                angleDiff(i) = 0;
            end
        end

        % desired spatial velocity
        u = (distanceDiff/(steps-count))/timestep;
        omega = (angleDiff/(steps-count))/timestep;
        
        % reduce singularity if exists
        if mani < mani_threshold
            damping_coefficient = (1-(mani/mani_threshold)^2)/damping_coefficient_MAX;
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
        checkLimit = CheckJointLimit(robot.model,qNext);
        if  checkLimit <= robot.model.n
            disp(['RMRC step ',num2str(count),'. Warning: exceed joint limit at joint ', num2str(checkLimit), ...
                '. A patch using IK solution is applied!']);
    
            % replace the invalid 'qNext' by an IK solution:
            poseNext = robot.model.fkine(qNext);
            qNext = robot.model.ikcon(poseNext,robot.model.getpos);
        end
        
        % move robot 
        robot.MoveRobot(qNext);

        % retrieve the current pose
        poseCurrent = robot.model.fkine(robot.model.getpos);
        
        % move the object if exists
        if objectExist
            object.Update(poseCurrent*objectTr);
        end
                
        % calculate the current error to the goal
        pointCurrent = poseCurrent(1:3,4);
        error_displacement = norm(pointFinal - pointCurrent);
    
        count = count+1;
    end
    
    % disp(['Current error is ',num2str(1000* error_displacement),'mm.']);
end