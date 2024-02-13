add-type -AssemblyName System.Numerics

function icadsample {
	return @(@{node = @{name = "part_a";
						xyz = @(0,0,0); xvec = @(1,0,0); yvec = @(0,1,0); zvec = @(0,0,1)};
			children = @()},
			@{node = @{name = "part_b";
						xyz = @(0,0.5,1.0); xvec = @(1,0,0); yvec = @(0,1,0); zvec = @(0,0,1)};
			children = @(
					@{node = @{name = "part_c";
								xyz = @(1.0,2.0,0); xvec = @(0,1,0); yvec = @(-1,0,0); zvec = @(0,0,1)};
					children = @()},
					@{node = @{name = "part_d";
								xyz = @(0,0,0); xvec = @(1,0,0); yvec = @(0,1,0); zvec = @(0,0,1)};
					children = @()})}
			)
}

function seek_icadtree {
	param($arr)

	$urdf = $arr | % { seek_icadpart $_ @{name = "world";
		xyz = @(0,0,0); xvec = @(1,0,0); yvec = @(0,1,0); zvec = @(0,0,1)} }
	return @{__tag = "robot"; name = "robot"; __body = $urdf}
}

function seek_icadpart {
	param($hash, $parent)

	if ($hash -eq $null) { return @() }

	$name = $hash.node.name
	$children = $hash.children
	$parentname = $parent.name
	$xyz = $hash.node.xyz -join " "
	$rpy = (uvector_to_rpy $hash.node.xvec $hash.node.yvec $hash.node.zvec) -join " "

	# fixed joint
	$urdf = @(@{__tag = "link"; name = $name;
			__body = @(@{__tag = "visual";
					__body = @(@{__tag = "geometry";
									__body = @(@{__tag = "mesh"; filename = "package://${name}.stl"})},
								@{__tag = "origin"; xyz = "0 0 0"; rpy = "0 0 0"},
								@{__tag = "material"; name = "gray";
									__body = @(@{__tag = "color"; rgba = "0.2 0.2 0.2 1.0"})})}
					)},
			@{__tag = "joint"; name = "joint-${name}"; type = "fixed";
							__body = @(@{__tag = "parent"; link = $parentname},
									@{__tag = "child"; link = $name},
									@{__tag = "origin"; xyz = $xyz; rpy = $rpy})})

	$hash.children | % { $urdf += (seek_icadpart $_) }

	return $urdf

	# revolute joint
#	$hash.node.joint = @{__tag = "joint"; name = "joint-${name}"; type = "revolute";
#							__body = @(@{__tag = "parent"; link = $parentname},
#									@{__tag = "child"; link = $name},
#									@{__tag = "origin"; xyz = $xyz; rpy = $rpy},
#									@{__tag = "axis"; xyz = ""},
#									@{__tag = "limit"; effort = "1000.0"; lower = ""; upper = ""; velocity = "1000.0"})}
}



# Hash型の機構木構造をURDF書式のstring型に変換して出力する
# 特殊キーの説明
#   "__tag"の値をXMLのタグ名に、"__body"の値(配列)をXMLの内部BODYとみなす
# 特殊キー以外は、タグの属性名とみなす
function to_xml {
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
				$b = to_xml $_ ($level + 1)
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
		return "${indent}<${name}${attrs}>`n${body}`n${indent}</${name}>"
	}

}

# 単位ベクトル3つ(配列)をRPY形式の配列に変換する
function uvector_to_rpy {
	param ($xvec, $yvec, $zvec)
	
	$mat = new-object System.Numerics.Matrix4x4($xvec[0], $yvec[0], $zvec[0], 0,
												$xvec[1], $yvec[1], $zvec[1], 0,
												$xvec[2], $yvec[2], $zvec[2], 0,
												0, 0, 0, 1)
	$quat = [System.Numerics.Quaternion]::CreateFromRotationMatrix($mat)
	$sy = 2.0 * $quat.X * $quat.Z + 2.0 * $quat.Y * $quat.W
	if ([Math]::Abs($sy) -gt 0.99999)
	{
		# オイラー角のジンバルロック
		return @([Math]::Atan2(2.0 * $quat.Y * $quat.Z + 2.0 * $quat.X * $quat.W,
					2.0 * $quat.W * $quat.W + 2.0 * $quat.Y * $quat.Y - 1),
				[Math]::Asin($sy),
				0.0)
	}
	else
	{
		return @([Math]::Atan2(2.0 * $quat.X * $quat.W - 2.0 * $quat.Y * $quat.Z,
								2.0 * $quat.W * $quat.W + 2.0 * $quat.Z * $quat.Z - 1.0),
				[Math]::Asin($sy),
				[Math]::Atan2(2.0 * $quat.Z * $quat.W - 2.0 * $quat.X * $quat.Y,
								2.0 * $quat.W * $quat.W + 2.0 * $quat.W * $quat.W - 1.0))
	}
}


