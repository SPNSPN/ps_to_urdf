function convert_to_urdf {
	param ([System.Collections.Hashtable] $tree, [int] $level = 0)

	$indent = "`t" * $level

	$name = ""
	$bodies = new-object System.Collections.Generic.List[string]
	$attrs = ""
	$tree.Keys | % {
		if ("__tag" -eq $_)
		{
			$name = $tree[$_]
		}
		elseif ("__body" -eq $_)
		{
			$tree["__body"] | % {
				$b = convert_to_urdf $_ ($level + 1)
				$bodies.add("${indent}$b")
			}
		}
		else
		{
			$value = $tree[$_]
			$attrs += " $_ = `"$value`""
		}
	}

	if ($bodies.Count -lt 1)
	{
		# bodyがないときは、閉じタグを1行に纏める
		return "${indent}<${name}${attrs}/>"
	}
	else
	{
		$body = $bodies -join "`n"
		return "${indent}<${name}${attrs}>`n${body}`n</${name}>"
	}

}
