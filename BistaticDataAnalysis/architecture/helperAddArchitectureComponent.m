function component = helperAddArchitectureComponent(arch, componentName, inPorts, outPorts, position)
%HELPERADDARCHITECTURECOMPONENT Add one logical component with its ports.

arguments
    arch
    componentName (1,1) string
    inPorts string
    outPorts string
    position (1,4) double
end

component = addComponent(arch, componentName);

if ~isempty(inPorts)
    inputDirections = repmat("in", size(inPorts));
    addPort(component.Architecture, inPorts, inputDirections);
end

if ~isempty(outPorts)
    outputDirections = repmat("out", size(outPorts));
    addPort(component.Architecture, outPorts, outputDirections);
end

set_param(component.SimulinkHandle, "Position", position);
end
