function port = helperAddArchitecturePort(arch, portName, direction, position)
%HELPERADDARCHITECTUREPORT Add one root architecture port and place it.

arguments
    arch
    portName (1,1) string
    direction (1,1) string {mustBeMember(direction, ["in" "out"])}
    position (1,4) double
end

port = addPort(arch, portName, direction);
set_param(port.SimulinkHandle, "Position", position);
end
