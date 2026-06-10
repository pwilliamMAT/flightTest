function quoted = helperQuotePosixArg(value)
%HELPERQUOTEPOSIXARG Quote one argument for a remote POSIX shell.

value = char(string(value));
quoted = ['''', strrep(value, '''', '''"''"'''), ''''];
end
