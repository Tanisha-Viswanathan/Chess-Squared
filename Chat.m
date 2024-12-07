% "char at"
function ch = chat(str, i)
  if isa(str, "string")
    str = str{:};
  end

  ch = str(i);
end
