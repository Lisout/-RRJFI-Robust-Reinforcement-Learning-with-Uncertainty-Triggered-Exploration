function replay = appendReplay(replay, observation, action, lowerReward, upperReward, nextObservation, done)
%APPENDREPLAY Insert one joint transition into a circular replay buffer.

arguments
    replay (1,1) struct
    observation (:,1) double
    action (:,1) double
    lowerReward (1,1) double
    upperReward (1,1) double
    nextObservation (:,1) double
    done (1,1) logical
end

position = mod(replay.position, replay.capacity) + 1;
replay.observation(:, position) = single(observation);
replay.action(:, position) = single(action);
replay.lowerReward(position) = single(lowerReward);
replay.upperReward(position) = single(upperReward);
replay.nextObservation(:, position) = single(nextObservation);
replay.done(position) = done;
replay.position = position;
replay.count = min(replay.count + 1, replay.capacity);
end

