function [value,hit] = helperLLCache(action,file,key,value)
%HELPERLLCACHE Exact metadata equality prevents stale cache reuse.
hit = false;
if action == "get"
    value = [];
    if isfile(file)
        saved = load(file,"key","value");
        if isequaln(saved.key,key)
            value = saved.value;
            hit = true;
        end
    end
else
    assert(action=="put","Unknown cache operation.");
    folder = fileparts(file);
    if ~isfolder(folder)
        mkdir(folder);
    end
    save(file,"key","value","-v7.3");
    hit = true;
end
end
