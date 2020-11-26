Set-Location pub:
function IsDerived {
  param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Item,
    [Parameter(Mandatory=$true)] $TemplateId
    )
  if($Item.TemplateID -ne "{0113F8CE-B4AE-4ADF-BBD2-390E230C92B3}"){
  	return [Sitecore.Data.Managers.TemplateManager]::GetTemplate($Item.TemplateID, $Item.Database).InheritsFrom($TemplateId)
  }
  else{
	  return 0
  }
}

function IsDerivedMultiple {
  param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Item,
    [Parameter(Mandatory=$true)] $TemplateList
    )
  
  foreach($template in $TemplateList)
  {
	$check = [Sitecore.Data.Managers.TemplateManager]::GetTemplate($Item.TemplateID, $Item.Database).InheritsFrom($template)
	if($check)
	{
	  return "true"
	}
  }
  return "false"
}

function validateImageField {
  param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $value,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $lang
    )
	
  if($value -eq "")
  {
	return "false"
  }
  if($value -eq " ")
  {
	return "false"
  }
  $id = $value.Split('"')
  if($id.Count -eq 1)
  {
	$id = $value.Split("'")
	if($id.Count -gt 1)
	{
		if($value.Contains("{"))
		{
			if($value.Contains("}"))
			{
				$idImage = ""
				$idImage += $value.Split("{")[1]
				$idImage = $idImage.Split("}")[0]
				$idImage = "{"+$idImage+"}"
				$item = Get-Item -Path pub: -ID $idImage -language $lang
				if($item)
				{
					$template = Get-Item -Path pub: -ID $item.TemplateID
					if($template.Paths.Path.Contains("Media"))
					{
						return "true"
					}
				}
			}
		}
	}
	return "false"
  }
  if($id.Count -gt 1)
  {
	if($value.Contains("{"))
	{
		if($value.Contains("}"))
		{
			$idImage = ""
			$idImage += $value.Split("{")[1]
			$idImage = $idImage.Split("}")[0]
			$idImage = "{"+$idImage+"}"
			$item = Get-Item -Path pub: -ID $idImage
			if($item)
			{
				$template = Get-Item -Path pub: -ID $item.TemplateID
				if($template.Paths.Path.Contains("Media"))
				{
					return "true"
				}
			}
		}
	}
   }
   return "false"
}

function generateChecksum{
	param(
		[Parameter(Mandatory=$true)] $value
		)
	
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
	$algorithm = [System.Security.Cryptography.HashAlgorithm]::Create('MD5')
	$StringBuilder = New-Object System.Text.StringBuilder 

	$algorithm.ComputeHash($bytes) | 
	ForEach-Object { 
	$null = $StringBuilder.Append($_.ToString("x2")) 
	} 

	return $StringBuilder.ToString()
}

function formatImageRichText {
  param(
    [Parameter(Mandatory=$true)] $richtext,
	[Parameter(Mandatory=$true)] $language,
	[Parameter(Mandatory=$true)] $baseURL
    )
  $checkashx = $richtext.Contains('.ashx')
  $checkmedia = $richtext.Contains('-/media/')
  if($checkashx)
  {
	if($checkmedia)
	{
	  $toupdate = $richtext -replace ".ashx", "≡"
	  $toupdate = $toupdate -replace 'src="-/media/', 'src="≡'
	  $toupdate = $toupdate -replace "src='-/media/", "src='≡"
	  $splited = $toupdate.Split("≡")
	  $i = 0
	  $result = ""
	  foreach($text in $splited)
	  {
		if(($i%2) -ne 0)
		{
			if($text.length -eq 32)
			{
				$guid = "{"
				$guid = $guid + [System.guid]::New($text) + "}"
				$itemImage = Get-Item -Path pub: -ID $guid -Language $language
				# $path = $itemImage.Paths.Fullpath
				# $path = $path -replace "/sitecore/media library/", "-/media/"
				$path = $baseURL+"/-/media/"+$text+".ashx"
				$path = $path -replace " ","%20"
				$path = $path +"==#"+$itemImage.Name+"==#"+$itemImage.Fields["Mime Type"]
				$result = $result+$path
			}
		}
		else{
			$result = $result + $text
		}
		$i = $i+1
	  }
	  $output = @{
		"richtext" = $result
		"isimagepresent" = "true"
	  }
	  return $output
	}
  }
  $result = @{
	"richtext" = $richtext
	"isimagepresent" = "false"
  }
  return $result
}

function formatLinkRichText {
  param(
    [Parameter(Mandatory=$true)] $richtext,
	[Parameter(Mandatory=$true)] $language,
	[Parameter(Mandatory=$true)] $replaceLink,
	[Parameter(Mandatory=$true)] $baseURL
    )
  $toupdate = $richtext -replace '~/link.aspx', "≡"
  $toupdate = $toupdate -replace "&amp;_z=z", "≡"
  
  $splited = $toupdate.Split("≡")
  $i = 0
  $result = ""
  foreach($text in $splited)
  {
	if(($i%2) -ne 0)
	{
		$splitedText = $text.Split("=")
		if($splitedText[1].length -eq 32)
		{
			$guid = "{"
			$guid = $guid + [System.guid]::New($splitedText[1]) + "}"
			try
			{
				$item = Get-Item -Path pub: -ID $guid -Language $language -ErrorAction SilentlyContinue -ErrorVariable myError
				if($item)
				{
					$url = [PG.ABBs.MultiBrand.Shared.Helpers.MultibrandUrlHelper]::GetUrlWithDomainName($item.Paths.Path, $baseURL)
					$url = $url -replace $replaceLink, ""
					$result = $result+$url
				}
				else{
					$result = $result + $text
				}
			}
			catch
			{
				$result = $result + $text
			}
		}
		else{
			$result = $result + $text
		}
	}
	else{
		$result = $result + $text
	}
	$i = $i+1
  }
  return $result
}

function removeSpaceLinkRichText {
  param(
    [Parameter(Mandatory=$true)] $richtext,
	[Parameter(Mandatory=$true)] $language,
	[Parameter(Mandatory=$true)] $replaceLink,
	[Parameter(Mandatory=$true)] $baseURL
    )
  $toupdate = $richtext -replace 'href="', "≡"
  $splited = $toupdate.Split("≡")
  $i = 0
  $result = ""
  foreach($text in $splited)
  {
	if($i -ne 0)
	{
		$splitedText = $text.Split('"')
		$j = 0
		foreach($split in $splitedText)
		{
			if($j -eq 0){
				$link = $split -replace " ","%20"
				$result = $result + 'href="' + $link
				$result = $result + '"'
			}
			else{ 
				$result = $result + '"' + $split 
			}
			$j = $j+1
		}
	}
	else{
		$result = $result + $text
	}
	$i = $i+1
  }
  return $result
}

function formatStyleRichText {
  param(
    [Parameter(Mandatory=$true)] $richtext
	)
  $isstyle = "false"
  $result = ""
  if($richtext.Contains("<style>"))
  {
	if($richtext.Contains("</style>"))
	{
		$processed = ""
		$processed += $richtext
		$processed = $processed -replace '<style>',"≡"
		$processed = $processed -replace '</style>',"≡"
		$splitedProcessed = $processed.Split("≡")
		$i = 0
		foreach($split in $splitedProcessed)
		{
			if($i -eq 0)
			{
				$result += $split
			}
			if($i -ne 0)
			{
				if(($i%2) -eq 0)
				{
					$result += $split
				}
			}
			$i++
		}
		$isstyle = "true"
	}
  }
  if(!$richtext.Contains("<style>"))
  {
	$result += $richtext
  }
  return @{
	"richtext" = $result
	"isstylepresent" = $isstyle
  }
}

function addToItemList {
	param(
		[Parameter(Mandatory=$true)] $tab,
		[Parameter(Mandatory=$true)] $element
	)
	$result =  New-Object System.Collections.ArrayList
	foreach($item in $tab)
	{
		if($item.Id -ne $element.Id)
		{
			$index = $result.add($item)
		}
	}
	$index = $result.add($element)
	return $result
}

function processAsset {
	param(
			[Parameter(Mandatory=$true)] $ListChild,
			[Parameter(Mandatory=$true)] $childId,
			[Parameter(Mandatory=$true)] $fieldName,
			[Parameter(Mandatory=$true)] $key
		)
	$concatenate = ''
	$appendLanguage = @{}
	$appendTitle = @{}
	$appendAltText = @{}
	$i=0
	$validated = "false"
	foreach($language in $languageList)
	{
		$value = $ListChild[$i][$childId].Fields[$fieldName].Value
		$checkValue = validateImageField -value $value -lang $language
		if($checkValue -eq "true")
		{
			$validated = "true"
			$checkAlt = $value.Contains('alt="')
			$checkSimpleAlt = $value.Contains("alt='")
			$altValue = ""
			if($checkAlt){
				$value = $value -replace 'alt="',"≡"
				$value = $value.Split('≡')[1].Split('"')[0]
				$altValue += $value
			}
			if($checkSimpleAlt){
				$value = $value -replace "alt='","≡"
				$value = $value.Split('≡')[1].Split("'")[0]
				$altValue += $value
			}
			$idImage = "{"
			$idImage = $idImage+$ListChild[$i][$childId].Fields[$fieldName].Value.Split('{')[1].Split('}')[0].Split(' ')[0]
			$idImage = $idImage+"}"
			$itemImage = Get-Item -Path pub: -ID $idImage -Language $languageList[$i]
			if($altValue -eq ""){
				$altValue += $itemImage.Fields["Alt"]
			}
			$mediaType = ""+$itemImage.fields["Mime Type"]
			$mediaName = $itemImage.Name
			$fileName = $itemImage.Name+"."+$mediaType.Split('/')[1]
			$imageURL = $itemImage.ID -replace("{", "")
			$imageURL = $imageURL -replace("}", "")
			$imageURL = $imageURL -replace("-", "")
			$imageURL = $siteURL[$i]+"-/media/"+$imageURL+".ashx"
			$appendLanguage += @{
				$languageList[$i] = @{
					"contentType" = $mediaType
					"fileName" = $fileName
					"upload" = $imageURL
				}
			}
			$appendTitle += @{
				$languageList[$i] = $fileName.Split('.')[0]
			}
			$appendAltText += @{
				$languageList[$i] = $altValue
			}
			$concatenate+= $fileName.Split('.')[0] + $mediaType + $fileName
		}
		$i++
	}
	if($validated -eq "true")
	{
		$appendfield = [ordered]@{
		$key = @{
				"fieldid" = $key
				"asset" = @{
					"fields" = @{
						"title" = @{ }
						"file" = @{ }
						"alt" = @{ }
					}
				}
			}
		}
		$appendField[$key].asset.fields.title += $appendTitle
		$appendField[$key].asset.fields.file += $appendLanguage
		$appendField[$key].asset.fields.alt += $appendAltText
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
		"validate" = $validated
	}
	return $result
}

function processRichText {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key
	)
	$concatenate = ''
	$appendField = [ordered]@{
		$key = @{
		}
	}
	$iteratorLang = 0
	$validate = "false"
	$isimage = "false"
	foreach($lang in $languageList)
	{
		$value = $ListChild[$iteratorLang][$childId].Fields[$fieldName].Value
		if($value -ne "")
		{
			$updatedStyle = formatStyleRichText -richtext $value
			$updatedImage = formatImageRichText -richtext $updatedStyle.richtext -language $lang -baseURL $siteURL[$iteratorLang]
			$updatedLink = formatLinkRichText -richtext $updatedImage.richtext -language $lang -baseURL $siteURL[$iteratorLang] -replaceLink $linkReplace[$iteratorLang]
			$updatedLink = removeSpaceLinkRichText -richtext $updatedLink -language $lang -baseURL $siteURL[$iteratorLang] -replaceLink $linkReplace[$iteratorLang]
			if($updatedImage.isimagepresent -eq "true")
			{
				$isimage = "true"
			}
			$add = @{
					$lang = $updatedLink
				}
			
			$iteratorLang++
			$appendField[$key]+=$add
			$concatenate+=$updatedLink
			$validate = "true"
		}
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
		"isimagepresent" = $isimage
		"validate" = $validate
		"isstylepresent" = $updatedStyle.isstylepresent
	}
	return $result
}

function processLink {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key
	)
	$concatenate = ''
	$appendField = [ordered]@{
		$key = @{
		}
	}
	$iteratorLang = 0
	$validate = "false"
	foreach($lang in $languageList)
	{
		$value = $ListChild[$iteratorLang][$childId].Fields[$fieldName].Value
		if($value -ne "")
		{
			if($value.Contains("url="))
			{
				$value = $value -replace 'url=',"≡"
				$value = $value.Split('≡')[1]
				$value = $value.Split('"')[1]
				if($value -ne "")
				{
					$add = @{
							$lang = $value
						}
					
					$iteratorLang++
					$appendField[$key]+=$add
					$concatenate+=$value
					$validate = "true"
				}
			}
		}
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
		"validate" = $validate
	}
	return $result
}

function processGeneralLink {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key
	)
	
	$concatenate = ''
	$appendField = [ordered]@{
		$key = @{
		}
	}
	$iteratorLang = 0
	$validate = "false"
	foreach($lang in $languageList)
	{
		$value = $ListChild[$iteratorLang][$childId].Fields[$fieldName].Value
		if($value -ne "")
		{
			if($value.Contains("url="))
			{
				$toaddvalue = $value -replace 'url=',"≡"
				$toaddvalue = $toaddvalue.Split('≡')[1]
				$toaddvalue = $toaddvalue.Split('"')[1]
				if($toaddvalue -ne "")
				{
					if($toaddvalue.Contains("https://youtu.be"))
					{
						$toaddvalue = $toaddvalue -replace "https://youtu.be","https://www.youtube.com/embed"
					}
					if($toaddvalue.Contains("http://youtu.be"))
					{
						$toaddvalue = $toaddvalue -replace "http://youtu.be","https://www.youtube.com/embed"
					}
					if($toaddvalue.Contains("https://www.youtube.com") -and !$toaddvalue.Contains("embed"))
					{
						if($toaddvalue.Contains("/watch?v="))
						{
							$idvideo = $toaddvalue -replace "h?v=","≡"
							$toaddvalue = "https://www.youtube.com/embed/"+$idvideo.Split("≡")[1]
						}
						else
						{
							$toaddvalue = $toaddvalue -replace "https://www.youtube.com","https://www.youtube.com/embed"
						}
					}
					$add = @{
							$lang = $toaddvalue
						}
					
					$iteratorLang++
					$appendField[$key]+=$add
					$concatenate+=$toaddvalue
					$validate = "true"
				}
			}
			if($value.Contains("id="))
			{
				$guid = $value -replace 'id=',"≡"
				$guid = $guid.Split('≡')[1]
				$guid = $guid.Split('"')[1]
				if($guid -ne "")
				{
					$item = Get-Item -Path pub: -ID $guid -Language $language
					$url = [PG.ABBs.MultiBrand.Shared.Helpers.MultibrandUrlHelper]::GetUrlWithDomainName($item.Paths.Path, $siteURL[$iteratorLang])
					$url = $url -replace $linkReplace[$iteratorLang], ""
					$add = @{
							$lang = $url
						}
					
					$iteratorLang++
					$appendField[$key]+=$add
					$concatenate+=$url
					$validate = "true"
				}
			}
		}
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
		"validate" = $validate
	}
	return $result
}

function processReferenceGeneralLink {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key
	)
	
	$concatenate = ''
	$appendField = [ordered]@{
		$key = @{
		}
	}
	$iteratorLang = 0
	$validate = "false"
	foreach($lang in $languageList)
	{
		$value = $ListChild[$childId].Fields[$fieldName].Value
		if($value -ne "")
		{
			if($value.Contains("url="))
			{
				$toaddvalue = $value -replace 'url=',"≡"
				$toaddvalue = $toaddvalue.Split('≡')[1]
				$toaddvalue = $toaddvalue.Split('"')[1]
				if($toaddvalue -ne "")
				{
					if($toaddvalue.Contains("https://youtu.be"))
					{
						$toaddvalue = $toaddvalue -replace "https://youtu.be","https://www.youtube.com/embed"
					}
					if($toaddvalue.Contains("http://youtu.be"))
					{
						$toaddvalue = $toaddvalue -replace "http://youtu.be","https://www.youtube.com/embed"
					}
					$add = @{
							$lang = $toaddvalue
						}
					
					$iteratorLang++
					$appendField[$key]+=$add
					$concatenate+=$toaddvalue
					$validate = "true"
				}
			}
			if($value.Contains("id="))
			{
				$guid = $value -replace 'id=',"≡"
				$guid = $guid.Split('≡')[1]
				$guid = $guid.Split('"')[1]
				if($guid -ne "")
				{
					$item = Get-Item -Path pub: -ID $guid -Language $language
					$url = [PG.ABBs.MultiBrand.Shared.Helpers.MultibrandUrlHelper]::GetUrlWithDomainName($item.Paths.Path, $siteURL[$iteratorLang])
					$url = $url -replace $linkReplace[$iteratorLang], ""
					$add = @{
							$lang = $url
						}
					
					$iteratorLang++
					$appendField[$key]+=$add
					$concatenate+=$url
					$validate = "true"
				}
			}
		}
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
		"validate" = $validate
	}
	return $result
}

function processChecklist{
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId
	)
	$iteratorlang = 0
	$checklistItem = @{
		"title" = @{ }
		"contentText" = @{ }
	}
	foreach($lang in $languageList)
	{
		$checklistItem.contentText += @{
			$lang = @{}
		}
		$titleAppend = @{
			$lang =  $ListChild[$iteratorLang][$childId].Fields['Pre Register 1 Title'].Value
		}
		$checklistItem.title += $titleAppend
		$items =  New-Object System.Collections.ArrayList
		$listElement = $ListChild[$iteratorLang][$childId].Fields["Pre Register 1 Item Picker"].Value.split('|')
		foreach($checklist in $listElement)
		{
			if($checklist.Contains('{') -and $checklist.Contains('}'))
			{
				$queryItem = "fast://*[@@id='"+$checklist+"']"
				$item = Get-Item -Path "pub:" -Query $queryItem -Language $lang
				if($item)
				{
					if($item.Fields['Pre Register Item Text'])
					{
						if($item.Fields['Pre Register Item Text'] -ne '')
						{
							$value = ""
							$value += $item.Fields['Pre Register Item Text'].Value
							$items.add($value)
						}
					}
				}
			}
		}
		$checklistItem.contentText[$lang] = $items
		$iteratorlang++
	}
	return $checklistItem
}

function processSymbol {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key
	)
	$concatenate = ''
	$appendField = [ordered]@{
		$key = @{
		}
	}
	$iteratorLang = 0
	foreach($lang in $languageList)
	{
		$value = $ListChild[$iteratorLang][$childId].Fields[$fieldName].Value
		$add = @{
				$lang = $value
			}
		
		$iteratorLang++
		$concatenate+=$value
		$appendField[$key]+=$add
	}
	$result = @{
		"append" = $appendField
		"concatenate" = $concatenate
	}
	return $result
}

function processReference {
	param(
		[Parameter(Mandatory=$true)] $ListChild,
		[Parameter(Mandatory=$true)] $childId,
		[Parameter(Mandatory=$true)] $fieldName,
		[Parameter(Mandatory=$true)] $key,
		[Parameter(Mandatory=$true)] $reference
	)
	$concatenate = ''
	$iteratorLang = 0
	$appendfield = [ordered]@{
		$key = @{ }
	}
	$check = "false"
	foreach($lang in $languageList)
	{
		$value = $ListChild[$iteratorLang][$childId].Fields[$fieldName].Value
		if($value -ne "" -and $value.Contains("{") -and $value.Contains("}"))
		{
			$queryItem = "fast://*[@@id='"+$value+"']"
			$referenceItem = Get-Item -Path "pub:" -Query $queryItem -Language $lang
			if(!$referenceItem)
			{
				$referenceItem = Get-Item -Path "pub:" -Query $queryItem
			}
			if($referenceItem)
			{
				$reference = addToItemList -tab $reference -element $referenceItem
				$added = "true"
				$ItemName = $referenceItem.Name
				$template = Get-Item -Path pub: -Id $referenceItem.TemplateID
				$name = ""
				if($referenceItem.TemplateID -eq "{54C9868B-B1BD-4CA8-ABE6-1A279130E48E}")
				{
					$path = $referenceItem.Paths.Path
					$path = $path -replace "sitecore/content/Pampers/",":"
					$splitedpath = $path.Split(":")[1].Split("/")
					$first = 0
					if($splitedpath.Count -eq 2)
					{
						$name = "categories-"+$referenceItem.Fields["Short Name"]
						if($referenceItem.Fields["Short Name"] -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$name = "categories-"+$referenceItem.Name
						}
					}
					if($splitedpath.Count -eq 3)
					{
						$parent = ""
						$nameitem = ""
						$parent += $referenceItem.Parent.Fields["Short Name"]
						if($parent -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$parent = ""
							$parent += $referenceItem.Parent.Name
						}
						$nameitem += $referenceItem.Fields["Short Name"]
						if($nameitem -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$nameitem = ""
							$nameitem += $referenceItem.Name
						}
						$name = "categories-"+$parent+"-"+$nameitem
					}
					if($splitedpath.Count -eq 4)
					{
						$parent = ""
						$nameitem = ""
						$parent += $referenceItem.Parent.Fields["Short Name"]
						if($parent -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$parent = ""
							$parent += $referenceItem.Parent.Name
						}
						$nameitem += $referenceItem.Fields["Short Name"]
						if($nameitem -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$nameitem = ""
							$nameitem += $referenceItem.Name
						}
						$parentparent = ""
						$parentparent += $referenceItem.Parent.Parent.Fields["Short Name"]
						if($parentparent -notmatch "^[a-zA-Z0-9\s]+$")
						{
							$parentparent = ""
							$parentparent += $referenceItem.Parent.Parent.Name
						}
						$name = "categories-"+$parentparent+"-"+$parent+"-"+$nameitem
					}
				}
				if($referenceItem.TemplateID -ne "{54C9868B-B1BD-4CA8-ABE6-1A279130E48E}")
				{
					$name = $ItemName
				}
				$name = $name -replace ' ',""
				$name = $name.ToLower()
				$appendValue = [ordered]@{
					$lang = @{
						"sys" = @{
							"type" = "Link" 
							"linkType" = "Entry"
							"id" = $name
						}
					}
				}
				$concatenate+="Link" + "Entry" + $name
				$appendfield[$key] += $appendValue
				$check="true"
			}
		}	
		$iteratorLang++
	}
	$result = @{
		"append" = $appendfield
		"concatenate" = $concatenate
		"references" = $reference
		"template" = $template.Name
		"validate" = $check
	}
	return $result
}

function processChild {
	param(
		[Parameter(Mandatory=$true)] $item,
		[Parameter(Mandatory=$true)] $referenceList
	)
	$Table = [ordered]@{
		‘list’ = @(
			
		)
	}
	$childiterator=0
	$items =  New-Object System.Collections.ArrayList
	$childLink = @{}
	$parentDisplayName = @{}
	$isstylepresent = "false"
	foreach($lan in $languageList)
	{
		$displayParent = ""
		$itemparent = Get-Item -Path pub: -ID $item.id -language $lan
		$displayParent += $itemparent.Fields["__Display Name"]
		$parentDisplayName += @{
			$lan = $displayParent
		}
		$itemPaths = "pub:"+$item.Paths.Path
		$listItem1 = Get-ChildItem -Language $lan -Path $itemPaths
		if($listItem1.Count -gt 1)
		{
			$index1 = $items.add($listItem1)
		}
		if($listItem1.Count -eq 1)
		{
			$subchildren =  New-Object System.Collections.ArrayList
			$index = $subchildren.add($listItem1)
			$index1 = $items.add($subchildren)
		}
		$childLink += @{
			$lan = @{
				"nodeType" = "document"
				"data" = @{ }
				"content" = @()
			}
		}
	}
	$checksumsubchildren=""
	foreach($subitem in $items[0]){
		$inherit = $subitem | IsDerivedMultiple -TemplateList $subContentTemplate
		if($inherit -eq "true")
		{
			$checkState = "false"
			$itemid = $subitem.id.guid
			$itemid = $itemid -replace '-',""
			$itemid = $itemid -replace ' ',""
			$itemid = $itemid.ToLower()
			foreach($language in $languageList){
				$item = Get-Item -Path pub: -ID $subitem.Id -Language $language
				$workflowstate = ""
				$workflowstate += $item.Fields["__Workflow state"].Value
				if($workflowstate -eq "")
				{
					$checkState = "Approved"
				}
				$workflowstate = $workflowstate -replace '{',""
				$workflowstate = $workflowstate -replace '}',""
				$workflowstate = $workflowstate -replace '-',""
				if($item.Fields["__Workflow state"].Value.Contains("{") -and $item.Fields["__Workflow state"].Value.Contains("}") -and $workflowstate.length -eq 32)
				{
					$state = Get-Item -Path pub: -ID $item.Fields["__Workflow state"]				
					if($state.Name -eq "Approved")
					{
						$checkState = "Approved"
					}
				}
				if($item.Fields["__Never publish"].Value -eq 1)
				{
					$checkState = "false"
				}
				if($checkState -eq "Approved")
				{
					$childLink[$language].content += @{
						"nodeType" = "embedded-entry-block"
						"content" = @()
						"data" = @{
							"target" = @{
								"sys" = @{
									"id" = $itemid
									"type" = "Link"
									"linkType" = "Entry"
								}
							}
						}
					}
					
				}
			}
			$checksumsubchildren+= "Link"+"Entry"+$itemid
			if($checkState -eq "Approved")
			{
				$concatenatedValue=''
				$concatenatedValueNoImage=''
				$itemName = $subitem.Name
				$itemName = $itemName -Replace ' ',''
				$itemName = $itemName.ToLower()
				$templId = $item.TemplateID
				$templId = $templId -replace '{',""
				$templId = $templId -replace '}',""
				$templId = $templId -replace '-',""
				$templId = $templId -replace ' ',""
				$templId = $templId.ToLower()
				$temp = Get-Item -Path pub: -ID $item.TemplateID
				$tempName = $temp.Name
				$tempName = $tempName -replace ' ',"-"
				$tempName = $tempName.ToLower()
				$Table2 = [ordered]@{
					"id" =$itemid
					"assetFieldsIdList" = @(
					
					)
					"itemId" = $subitem.id
					"language" = $languageList
					"checksum" = @{}
					"subcontent" = @{}
					"template" = $tempName
					"checksumWithoutImage" = @{}
					"isstylepresent" = "false"
					"displayName" = @{
					
					}
					"item" = 
						@{
							"fields" = 
								@{
									
								}
						}
				}
				$languageiterator = 0
				foreach($lan in $languageList){
					$name = ""
					$name += $items[$languageiterator][$childiterator].Fields["__Display Name"]
					 $Table2.displayName += @{
						$lan = $parentDisplayName[$lan] + "-" + $name
					 }
					$languageiterator++
				}
				$allChildFields = Get-ItemField -Item $subitem -ReturnType Field -Name "*"
				foreach($field in $allChildFields)
				{
					$stringkey = $field.Name
					$stringkey = $stringkey -replace ' ',""
					$stringkey = $stringkey.ToLower()
					$stringkey = $stringkey + "sitecore"
					$checkField = $field.Name.Contains("__")
					if(!$checkField)
					{
						if($field.Type -eq "Single-Line Text")
						{
							$append = processSymbol -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							$concatenatedValue += $append.concatenate
							$concatenatedValueNoImage += $append.concatenate
							$Table2.item.fields+=$append.append
						}
						if($field.Type -eq "Image")
						{
							$append = processAsset -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							if($append.validate -eq "true")
							{
								$concatenatedValue += $append.concatenate
								$Table2.item.fields+=$append.append
								$Table2.assetFieldsIdList+=$stringkey
							}
						}
						if($field.Type -eq "Rich Text")
						{
							$append = processRichText -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							if($append.validate -eq "true")
							{
								if($append.isimagepresent -eq "false")
								{
									$concatenatedValue += $append.concatenate
									$concatenatedValueNoImage += $append.concatenate
								}
								$Table2.item.fields+=$append.append
								if($Table2.isstylepresent -eq "false")
								{
									$Table2.isstylepresent = $append.isstylepresent
								}
								if($isstylepresent -eq "false")
								{
									$isstylepresent = $append.isstylepresent
								}
							}
						}
						if($field.Type -eq "General Link" -and $field.Name -eq "URL")
						{
							$append = processGeneralLink -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							if($append.validate -eq "true")
							{
								$concatenatedValue += $append.concatenate
								$concatenatedValueNoImage += $append.concatenate
								$Table2.item.fields+=$append.append
							}
						}
						if($field.Type -eq "General Link" -and $field.Name -eq "Video URL")
						{
							$append = processGeneralLink -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							if($append.validate -eq "true")
							{
								$concatenatedValue += $append.concatenate
								$concatenatedValueNoImage += $append.concatenate
								$Table2.item.fields+=$append.append
							}
						}
						if($field.Type -eq "General Link" -and $field.Name -eq "Image Link")
						{
							$append = processGeneralLink -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey
							if($append.validate -eq "true")
							{
								$concatenatedValue += $append.concatenate
								$concatenatedValueNoImage += $append.concatenate
								$Table2.item.fields+=$append.append
							}
						}
						# if($field.Type.Contains("Droplink") -or $field.Type.Contains("tree") -or $field.Type.Contains("Tree"))
						# {
							# $append = processReference  -ListChild $items -childId $childiterator -fieldName $field.Name -key $stringkey -reference $referenceList
							# $concatenatedValue+=$append.concatenate
							# $concatenatedValueNoImage+=$append.concatenate
							# $referenceList =$append.references
							# $Table2.item.fields+=$append.append
						# }
					}
				}
				$Table2.item.fields+=@{
					"displaynamesitecore" = $Table2.displayName
				}
				$itemPathsPath = "pub:"+$items[0][$childiterator].Paths.Path
				$subItem1 = Get-ChildItem -Path $itemPathsPath
				if($subItem1.Count -gt 0)
				{
					$subcontent = processChild -item $items[0][$childiterator] -referenceList $referenceList
					$Table2.item.fields+=@{
						"subcontent" = $subcontent.childlink
					}
					$Table2.subcontent = $subcontent.table
					$referenceList = $subcontent.references
				}
				#Generate Checksum
				$Table2.checksum = generateChecksum -value $concatenatedValue
				$Table2.checksumWithoutImage = generateChecksum -value $concatenatedValueNoImage
				# $Table2.checksum = $concatenatedValue.length
				# $Table2.checksumWithoutImage = $concatenatedValueNoImage.length
				$Table.list+=$Table2
			}
		}
		$childiterator++
	}
	$result = @{
		"table" = $Table
		"references" = $referenceList
		"childlink" = $childLink
		"checksumchild" = $checksumsubchildren
		"isstylepresent" = $isstylepresent
	}
	return $result
}

function processFlexibleBanner{
	param(
		[Parameter(Mandatory=$true)] $settingPath
	)
	$element = @{
		"id" = "flexiblebannerentry"
		"assetFieldsIdList" = @(
		
		)
		"language" = $languageList
		"checksum" = @{}
		"checksumWithoutImage" = @{}
		"item" = 
			@{
				"fields" = 
					@{
						"title" = @{}
					}
			}
	}

	$pathSetting = "Pub:"
	$pathSetting += $settingPath
	$listItem =  New-Object System.Collections.ArrayList
	foreach($lang in $languageList){
		$listLang  =  New-Object System.Collections.ArrayList
		$settingItem = Get-Item -Path $pathSetting -language $lang
		$banner = "Pub:"
		$banner += $settingItem.Fields['Banner Source'].Value
		$bannerItem = Get-Item -Path $banner -language $lang
		$appendLang = @{
			$lang = "flexible banner"
		}
		$listLang.add($bannerItem)
		$listItem.add($listLang)
		$element.item.fields.title += $appendLang
	}
	$appendUrl = processGeneralLink -ListChild $listItem -childId 0 -fieldName "Action Url" -key "url"
	$appendImage2 = processAsset -ListChild $listItem -childId 0 -fieldName "Image Box Size 2" -key "imageMobile"
	$appendImage3 = processAsset -ListChild $listItem -childId 0 -fieldName "Image Box Size 3" -key "imageDesktop"
	$element.item.fields += $appendUrl.append
	$element.item.fields += $appendImage2.append
	$element.item.fields += $appendImage3.append
	$element.assetFieldsIdList += "imageMobile"
	$element.assetFieldsIdList += "imageDesktop"

	return $element
}


# All fields set to localized
#
#
#
#
$configFilePath = "F:\xxxx\xxxxx\xxxxx\xxx\config-affiliate-articles.txt"

$languageConfig = (Get-Content -Path $configFilePath -TotalCount 1)
$linkReplaceConfig = (Get-Content -Path $configFilePath -TotalCount 2)[-1]
$siteUrlConfig = (Get-Content -Path $configFilePath -TotalCount 3)[-1]
$cloudinarySiteURLConfig = (Get-Content -Path $configFilePath -TotalCount 4)[-1]
$articleTemplateConfig = (Get-Content -Path $configFilePath -TotalCount 5)[-1]
$subContentTemplateConfig = (Get-Content -Path $configFilePath -TotalCount 6)[-1]
$referenceTemplateConfig = (Get-Content -Path $configFilePath -TotalCount 7)[-1]
$fieldsConfig = (Get-Content -Path $configFilePath -TotalCount 8)[-1]
$parentPathConfig = (Get-Content -Path $configFilePath -TotalCount 9)[-1]
$repoPathConfig = (Get-Content -Path $configFilePath -TotalCount 10)[-1]
$articlePathConfig = (Get-Content -Path $configFilePath -TotalCount 11)[-1]
$siteSettings = (Get-Content -Path $configFilePath -TotalCount 12)[-1]

$language = $languageConfig.Split("=")[1].Split("|")[0]
$languageList = $languageConfig.Split("=")[1].Split("|")
$linkReplace = $linkReplaceConfig.Split("=")[1].Split("|")
$siteURL = $siteUrlConfig.Split("=")[1].Split("|")
$cloudinarySiteURL = $cloudinarySiteURLConfig.Split("=")[1].Split("|")
$articleTemplate = $articleTemplateConfig.Split("=")[1]
$subContentTemplate = $subContentTemplateConfig.Split("=")[1].Split("|")
$referenceTemplate = $referenceTemplateConfig.Split("=")[1].Split("|")
$articlePath = $articlePathConfig.Split("=")[1].Split("|")
$siteSettingsPath = $siteSettings.Split("=")[1]

$FieldsList = $fieldsConfig.Split("=")[1].Split("|")
$FieldsList1 = $fieldsConfig.Split("=")[1].Split("|")

$parentItem = $parentPathConfig.Split("=")[1]

$repoPath = $repoPathConfig.Split("=")[1]
$parentItem = "pub:"+$parentItem
$children =  New-Object System.Collections.ArrayList
$referencedItemList =  New-Object System.Collections.ArrayList
foreach($lan in $languageList)
{
	$listItem1 = Get-ChildItem -Language $lan -Path $parentItem -recurse
	if($listItem1.Count -gt 1)
	{
		$index1 = $children.add($listItem1)
	}
	if($listItem1.Count -eq 1)
	{
		$subchildren =  New-Object System.Collections.ArrayList
		$index = $subchildren.add($listItem1)
		$index1 = $children.add($subchildren)
	}
}

$item = New-Object System.Object



$Table = [ordered]@{
		‘articles’ = @(
			
		)
}

$TableSubContentTemplate = [ordered]@{
		‘articles’ = @(
		
		)
}

$appendTemplate = [ordered]@{
	"id" = "template"+$articleTemplate -Replace '[{}-]',''
	"item" = @{
	
	}
}

$idstring = ""+$children[0][0].Fields[$FieldsList[0].Split(':')[0]].id.Guid+""
$displayFieldId = "field"+$idstring -Replace '-',''
$displayFieldName = $FieldsList[0].Split(':')[0]
$displayFieldName = $displayFieldName -replace ' ',""
$displayFieldName = $displayFieldName.ToLower() + "contentful"
$itemTemplate = Get-Item -Path pub: -Id $articleTemplate
$appendTemplateItem = [ordered]@{
	"name" = $itemTemplate.Name
	"description" = "template description"
	"displayField" = $displayFieldName
	"fields" = @(
	
	)
}

# Items JSON
$iterator=0
foreach($child in $children[0]){
    $inherit = $child | IsDerived -TemplateId $articleTemplate
	$childId = ""+$child.id.Guid+""
	$childId = $childId -Replace '-',''
    if($child.TemplateID -eq $articleTemplate){
		$checkState = "false"
		foreach($language in $languageList){
			$item = Get-Item -Path pub: -ID $child.Id -Language $language
			$workflowstate = ""
			$workflowstate += $item.Fields["__Workflow state"].Value
			if($workflowstate -eq "")
			{
				$checkState = "Approved"
			}
			$workflowstate = $workflowstate -replace '{',""
			$workflowstate = $workflowstate -replace '}',""
			$workflowstate = $workflowstate -replace '-',""
			if($item.Fields["__Workflow state"].Value.Contains("{") -and $item.Fields["__Workflow state"].Value.Contains("}") -and $workflowstate.length -eq 32)
			{
				$state = Get-Item -Path pub: -ID $item.Fields["__Workflow state"]				
				if($state.Name -eq "Approved")
				{
					$checkState = "Approved"
				}
			}
			if($item.Fields["__Never publish"].Value -eq 1)
			{
				$checkState = "false"
			}
		}
		if($checkState -eq "Approved")
		{
			$checklistIsPeresent = 0
			$concatenatedValue=''
			$concatenatedValueNoImage=''
			$itemName=''
			$itemName = $child.Name
			$category = Get-Item -Path pub: -ID $child.Fields["Selected Category"]
			$itemName += "-" + $category.Name
			$itemName = $itemName -Replace ' ',''
			$itemName = $itemName.ToLower()
			$itemid = $child.id.guid
			$itemid = $itemid -replace '-',''
			$Table2 = [ordered]@{
				"id" = $itemid
				"assetFieldsIdList" = @(
				
				)
				# "itemId" = $child.id
				"language" = $languageList
				"checksum" = @{}
				"checksumWithoutImage" = @{}
				"displayName" = @{
				
				}
				"isstylepresent" = "false"
				"subcontent" = @{ }
				"checklist" = @{ 
					"title" = @{ }
					"content" = @{}
				}
				"item" = 
					@{
						"fields" = 
							@{
								"displaynamesitecore" = @{}
								"displaynameslugsitecore" = @{}
								"patharticlesitecore" = @{}
								"datesitecore" = @{}
							}
					}
			}
			$languageiterator = 0
			$subcontentField = @{ }
			foreach($lan in $languageList){
				$created = ""
			    $updated = ""
				$datesitecore = ""
				if($children[$languageiterator][$iterator].Fields["Is A Baby Development Article"]){
					$checklistIsPeresent = 1
				}
				if($children[$languageiterator][$iterator].Fields["Display Date"])
				{
					$appendDate = ""
					$appendDate += $children[$languageiterator][$iterator].Fields["Display Date"]
					if($appendDate.Contains("T") -and !$appendDate.Contains("$"))
					{
						$datesitecore += $appendDate.Split('T')[0]
						$datesitecore = $datesitecore.substring(0,4)+"-"+$datesitecore.substring(4,2)+"-"+$datesitecore.substring(6,2)
					}
				}
				if($datesitecore -eq "")
				{
					$created += $children[$languageiterator][$iterator].Fields["__Created"]
					$updated += $children[$languageiterator][$iterator].Fields["__Updated"]
					$created = $created.Split('T')[0]
					$updated = $updated.Split('T')[0]
					if($updated -ne "")
					{
						$datesitecore += $updated.substring(0,4)+"-"+$updated.substring(4,2)+"-"+$updated.substring(6,2)
					}
					if($updated -eq "")
					{
						$datesitecore += $created.substring(0,4)+"-"+$created.substring(4,2)+"-"+$created.substring(6,2)
					}
				}
				$subcategoryitem = Get-Item -Path pub: -ID $category.Id -language $lan
				$categoryitem = Get-Item -Path pub: -ID $subcategoryitem.Parent.Id -language $lan
				$pathcat = "/"
				$pathcat += $categoryitem.Fields["Short Name"] 
				$pathcat += "/" 
				$pathcat += $subcategoryitem.Fields["Short Name"]
				$pathcat = $pathcat -replace ' ',"-"
				$pathcat = $pathcat.ToLower()
				$name = ""
				$name += $children[$languageiterator][$iterator].Fields["__Display Name"]
				$patharticle = $name
				$patharticle = $patharticle -replace ' ',"-"
				$patharticle = $patharticle.ToLower()
				$article = $articlePath[$languageiterator]
				$article = $article -replace ' ',"-"
				$article = $article.ToLower()
				 $Table2.displayName += @{
					$lan = $name
				 }
				 $Table2.item.fields.displaynamesitecore += @{
					$lan = $name
				 }
				 $Table2.item.fields.displaynameslugsitecore += @{
					$lan = $patharticle
				 }
				 $Table2.item.fields.patharticlesitecore += @{
					$lan = $pathcat+"/"+$article+"/"+$patharticle
				 }
				 $Table2.item.fields.datesitecore += @{
					$lan = $datesitecore
				 }
				$subcontentField = @{
					$lan = @{
						"nodeType" = "document"
						"data" = @{}
						"content" = @{}
					}
				}
				$languageiterator++
			}	
			foreach($field in $FieldsList1)
			{
				$fieldTitle = $field.Split(':')[0]
				$stringkey = ""+$child.Fields[$fieldTitle].id.Guid+""
				$stringkey = $fieldTitle -replace ' ',""
				$stringkey = $stringkey.ToLower()
				$stringkey = $stringkey + "sitecore"
				$name = $name.ToLower()
				$value = $child.Fields[$fieldTitle].Value
				if($field.Split(':')[2] -eq "Asset")
				{
					$append = processAsset -ListChild $children -childId $iterator -fieldName $field.Split(':')[0] -key $stringkey
					if($append.validate -eq "true")
					{
						$Table2.assetFieldsIdList+=$stringkey
						$Table2.item.fields+=$append.append
						$concatenatedValue+=$append.concatenate
					}
				}
				if($field.Split(':')[2] -eq "Text")
				{
					$append = processRichText -ListChild $children -childId $iterator -fieldName $field.Split(':')[0] -key $stringkey
					if($append.validate -eq "true")
					{
						if($append.isimagepresent -eq "false")
						{
							$concatenatedValue += $append.concatenate
							$concatenatedValueNoImage += $append.concatenate
						}
						$Table2.item.fields+=$append.append
						if($Table2.isstylepresent -eq "false")
						{
							$Table2.isstylepresent = $append.isstylepresent
						}
					}
				}
				if($field.Split(':')[2] -eq "Symbol")
				{
					$append = processSymbol -ListChild $children -childId $iterator -fieldName $field.Split(':')[0] -key $stringkey
					$concatenatedValue+=$append.concatenate
					$concatenatedValueNoImage+=$append.concatenate
					$Table2.item.fields+=$append.append
				}
				if($field.Split(':')[2] -eq "Entry")
				{
					$append = processReference  -ListChild $children -childId $iterator -fieldName $field.Split(':')[0] -key $stringkey -reference $referencedItemList
					if($append.validate -eq "true")
					{
						$concatenatedValue+=$append.concatenate
						$concatenatedValueNoImage+=$append.concatenate
						$referencedItemList = $append.references
						$Table2.item.fields+=$append.append
					}
				}
			}
			# $checksumNoImages = generateChecksum -value $concatenatedValueNoImage
			$childData = processChild -item $child -referenceList $referencedItemList
			#Append subcontent
			$Table2.item.fields+=@{
				"subcontent" = $childData.childlink
			}
			$Table2.subcontent = $childData.table
			$referencedItemList = $childData.references
			if($Table2.isstylepresent -eq "false")
			{
				$Table2.isstylepresent = $childData.isstylepresent
			}
			
			#Generate Checksum
			# $concatenatedValue += $childData.checksumchild
			# $concatenatedValueNoImage += $childData.checksumchild
			
			$Table2.checksum = generateChecksum -value $concatenatedValue
			$Table2.checksumWithoutImage = generateChecksum -value $concatenatedValueNoImage
			# $Table2.checksum = $concatenatedValue.length
			# $Table2.checksumWithoutImage = $concatenatedValueNoImage.length
			

			if($checklistIsPeresent){
				$checklists = processChecklist -ListChild $children -childId $iterator
				$Table2.checklist.title = $checklists.title
				$Table2.checklist.content = $checklists.contentText
			}

			$Table.articles+=$Table2
		}
	}
	$iterator++
}

$TableReference = [ordered]@{
		‘articles’ = @(
			
		)
}
$refiterator = 0
$listRef = $referencedItemList
foreach($referenced in $referencedItemList)
{
	$concatenatedValue=""
	$referencedTable = [ordered]@{
		"id" = @{}
		"assetFieldsIdList" = @()
		"language" = $languageList
		"checksum" = @{}
		"referencefields" = @()
		"subcontent" = @{ }
		"displayName" = @{
		
		}
		"itemName" = @{}
		"parentItemName" = @{}
		"rootName" = @{}
		"item" = 
			@{
				"fields" = 
					@{

					}
			}
	}
	$checkItem = "false"
	$item = $referenced
	$urlsitecore = @{}
	$itlanguage = 0
	$name = ""
	foreach($lan in $languageList)
	{
		$queryrefItem = "fast://*[@@id='"+$referenced.Id+"']"
		$item = Get-Item -Path "pub:" -Query $queryrefItem -Language $lan
		if($item)
		{
			$checkItem = "true"
		}
		if(!$item -and $checkItem -ne "true")
		{
			$item = Get-Item -Path "pub:" -Query $queryrefItem
		}
		if($item.TemplateID -eq "{54C9868B-B1BD-4CA8-ABE6-1A279130E48E}")
		{
			$path = $item.Paths.Path
			$path = $path -replace "sitecore/content/Pampers/",":"
			$splitedpath = $path.Split(":")[1].Split("/")
			$appendName = ""
			$appendName += $item.Fields["Short Name"]
			if($appendName -notmatch "^[a-zA-Z0-9\s]+$")
			{
				$appendName = ""
				$appendName += $item.Name
			}
			if($splitedpath.Count -eq 2)
			{
				$url = ""
				$url += ""+$siteURL[$itlanguage] + "/"
				$url += ""+$appendName
				$url = $url -replace ' ',"-"
				$url = $url.ToLower()
				$referencedTable.item.fields+= @{
					"urlsitecore" = @{}
				}
				$referencedTable.item.fields.urlsitecore += @{
					$lan = $url
				}
				$referencedTable.itemName = ""+$appendName
				$referencedTable.parentItemName = "Categories"
				$referencedTable.rootName = "Root"
				$name = "categories-"+$appendName
			}
			if($splitedpath.Count -eq 3)
			{
				$appendParent = ""
				$appendParent += $item.Parent.Fields["Short Name"]
				if($appendParent -notmatch "^[a-zA-Z0-9\s]+$")
				{
					$appendParent = ""
					$appendParent += $item.Parent.Name
				}
				$url = ""
				$url += ""+$siteURL[$itlanguage] + "/"
				$url += ""+$appendParent + "/" + $appendName
				$url = $url -replace ' ',"-"
				$url = $url.ToLower()
				$referencedTable.item.fields+= @{
					"urlsitecore" = @{}
				}
				$referencedTable.item.fields.urlsitecore += @{
					$lan = $url
				}
				$referencedTable.itemName = ""+$appendName
				$referencedTable.parentItemName = ""+$appendParent
				$referencedTable.rootName = "Categories"
				$name = "categories-"+$appendParent+"-"+$appendName
			}
			if($splitedpath.Count -eq 4)
			{
				$appendParent = ""
				$appendParent += $item.Parent.Fields["Short Name"]
				if($appendParent -notmatch "^[a-zA-Z0-9\s]+$")
				{
					$appendParent = ""
					$appendParent += $item.Parent.Name
				}
				
				$appendParentParent = ""
				$appendParentParent += $item.Parent.Parent.Fields["Short Name"]
				if($appendParentParent -notmatch "^[a-zA-Z0-9\s]+$")
				{
					$appendParentParent = ""
					$appendParentParent += $item.Parent.Parent.Name
				}
				$url = ""
				$url += ""+$siteURL[$itlanguage] + "/"
				$url += ""+$appendParentParent + "/" + $appendParent + "/" + $appendName
				$url = $url -replace ' ',"-"
				$url = $url.ToLower()
				$referencedTable.item.fields+= @{
					"urlsitecore" = @{}
				}
				$referencedTable.item.fields.urlsitecore += @{
					$lan = $url
				}
				$referencedTable.itemName = ""+$appendName
				$referencedTable.parentItemName = ""+$appendParent
				$referencedTable.rootName = ""+$appendParentParent
				$name = "categories-"+$appendParentParent+"-"+$appendParent+"-"+$appendName
			}
		}
		$itlanguage ++
	}
	if($item.TemplateID -ne "{54C9868B-B1BD-4CA8-ABE6-1A279130E48E}")
	{
		$name = $item.Name
	}
	$name = $name.ToLower()
	$name = $name -replace ' ',""
	$referencedTable.id = $name
	# $referencedTable.itemName = $splitedpath[$splitedpath.length-1]
	# $referencedTable.parentItemName = $splitedpath[$splitedpath.length-2]
	# $referencedTable.rootName = $splitedpath[$splitedpath.length-3]
	$allReferenceFields = Get-ItemField -Item $item -ReturnType Field -Name "*"
	foreach($field in $allReferenceFields)
	{
		$name = $field.Name
		$name = $name -replace ' ',""
		$name = $name.ToLower()
		$name = $name + "sitecore"
		$appendField = @{ }
		# if($field.Type.Contains("Droplink") -or $field.Type.Contains("Multi List") -or $field.Type.Contains("Multilist") -or $field.Type.Contains("tree") -or $field.Type.Contains("Tree") )
		# {
			# $referencedTable.referencefields+=@{
				# "name" = $field.Name
			# }
		# }
		
		$checkField = $field.Name.Contains("__")
		if(!$checkField)
		{
			foreach($lan in $languageList)
			{
				$queryreflangItem = "fast://*[@@id='"+$referenced.Id+"']"
				$item = Get-Item -Path "pub:" -Query $queryreflangItem -Language $lan
				if(!$item)
				{
					$item = Get-Item -Path "pub:" -Query $queryreflangItem
				}
				$checkField = $field.Name.Contains("__")
				if(!$checkField -and $field.Type -eq "Single-Line Text")
				{
					$appendField  += @{
						$lan = $item.Fields[$field.Name].Value
					}
					$concatenatedValue+=$item.Fields[$field.Name].Value
				}
			}
		}
		$checkField = $field.Name.Contains("__")
		if(!$checkField -and $field.Type -eq "Single-Line Text")
		{
			$referencedTable.item.fields += @{
				$name = $appendField
			}
		}
		if(!$checkField -and $field.Type -eq "General Link"){
			$append = processReferenceGeneralLink -ListChild $listRef -childId $refiterator -fieldName $field.Name -key $name
			if($append.validate -eq "true")
			{
				$referencedTable.item.fields+=$append.append
			}
		}
	}
	$referencedTable.item.fields += @{
		"displaynamesitecore" = @{}
	}
	foreach($lan in $languageList)
	{
		$referencedTable.item.fields.displayname += @{
			$lan = $item.Name
		}
	}
	$referencedTable.checksum = generateChecksum -value $concatenatedValue
	$TableReference.articles+=$referencedTable
	$refiterator++
}
$Table += @{
	"references" = $TableReference
}

$itembanner = processFlexibleBanner -settingPath $siteSettingsPath

$TableBanner = [ordered]@{
		‘articles’ = $itembanner
}
$Table += @{
	"banner" = $TableBanner
}

$result = $Table | ConvertTo-Json -Depth 20 -compress

$resultRef = $TableReference | ConvertTo-Json -Depth 13 -compress

New-Item -Path "F:\xxxxx\xxxxxxx\xxxxxx\" -Name "export-affiliate-data-result.json" -Value $result
