package de.fraunhofer.ipa.deployment.generator

import com.google.common.base.CaseFormat
import de.fraunhofer.ipa.deployment.deployModel.BuildRequirements
import de.fraunhofer.ipa.deployment.deployModel.CISetting
import de.fraunhofer.ipa.deployment.deployModel.GitPackage
import de.fraunhofer.ipa.deployment.deployModel.GroupedProperties
import de.fraunhofer.ipa.deployment.deployModel.MonolithicImplementationDescription
import de.fraunhofer.ipa.deployment.deployModel.PackageDescription
import de.fraunhofer.ipa.deployment.deployModel.impl.CommonPropertyMultiValueImpl
import de.fraunhofer.ipa.deployment.deployModel.impl.CommonPropertySingleValueImpl
import de.fraunhofer.ipa.deployment.deployModel.impl.MultiValueListBracketImpl
import de.fraunhofer.ipa.deployment.deployModel.impl.MultiValueListPreListImpl
import de.fraunhofer.ipa.deployment.utils.DeployModelUtils
import de.fraunhofer.ipa.deployment.validation.CommonRules
import de.fraunhofer.ipa.deployment.validation.CommonRules.BranchPrefixTypes
import de.fraunhofer.ipa.deployment.validation.CommonRules.GitlabDefaultRunnerTags
import java.util.List
import java.util.Map
import java.util.stream.Collectors
import org.eclipse.emf.common.util.EList

import static extension de.fraunhofer.ipa.deployment.utils.DeployModelUtils.*

class GitLabCICompiler {
	DeployModelUtils utils = new DeployModelUtils()
	
	CIGeneratorHelper ciHelper = new CIGeneratorHelper()
	var commonVariableList = ciHelper.setEnvVaribalesCommon()
	var dockerRunnerSaveCacheFlag = false
	var dockerRunnerNoCacheFlag = false
	var simpleRunnerFlag = false
	
	var builderRepo = "ghcr.io/ipa-rwu/"

	def compileGitlabCI(MonolithicImplementationDescription monImpl)'''
  «val variableMap = commonVariableList.toMap([it], ['""'])»
  «addVariables(variableMap, monImpl)»
	'''

	def compileGitlabCI(
  	MonolithicImplementationDescription monImpl,
  	PackageDescription pkgDes,
  	CISetting ciSetting
  )'''
  «val variableMap = commonVariableList.toMap([it], ['""'])»
  «addVariables(variableMap, monImpl, pkgDes, ciSetting)»
  «addCommonBlock(pkgDes, ciSetting)»
  «IF ciSetting.reqBranchPrefix == DeployModelUtils.camelToLowerUnderscore(BranchPrefixTypes.None.name())»
  «findRosDistroFromBranchPrefix()»
  «ENDIF»
  «commonBuild()»
  «build(monImpl, ciSetting)»
  «commonPublish()»
  «publish(monImpl, pkgDes, ciSetting)»
	'''
	

	/*****************************************************/
	/*
	 * fill Variables
	 */
  def fillVaribalesFromMonImpl(
  	Map<String, String> variableMap,
  	MonolithicImplementationDescription monImpl
  	){
  	variableMap.put('PREFIX', '"${CI_REGISTRY_IMAGE}/${CI_PIPELINE_ID}:"')
  	variableMap.put('BUILDER_PREFIX', String.format('"%s"',builderRepo))
  	variableMap.put('BUILDER_SUFFIX', '":latest"')
  	variableMap.put('FOLDER', '${CI_JOB_NAME}')
  	variableMap.put('NAME', '${CI_JOB_NAME}')
  	variableMap.put('DOCKER_BUILDKIT', '1')
  	setVariableDockerTLS(variableMap, "")
  	setVariableROSDistros(variableMap,	monImpl.implementation.buildRequirements.reqRosDistros.values)

  	if(monImpl.implementation.buildRequirements.reqBuildDependencies !== null){
  		for(dep: monImpl.implementation.buildRequirements.reqBuildDependencies.dependencies){
	  		if(dep.class == GitPackage){
				  	setVariablePrivateRepoToken(variableMap, (dep as GitPackage).visibility)
	  			}
	  		}
  	}

  	if(monImpl.implementation.buildRequirements.reqCMakeArgs !== null){
  		setVariableCMakeArgs(variableMap, monImpl.implementation.buildRequirements.reqCMakeArgs.values)
  	}
	}

	def getObjectListValues(Object object){
		if(object.class == MultiValueListBracketImpl){
			return (object as MultiValueListBracketImpl).values
		}
		if(object.class == MultiValueListPreListImpl){
			return (object as MultiValueListPreListImpl).values
		}
		return null
	}
	
	def fillVaribalesFromPackage(
  	Map<String, String> variableMap,
  	PackageDescription pkg
  ){
  	for(v: pkg.imageDescription.types.values){
  		if (CaseFormat.UPPER_UNDERSCORE.to(CaseFormat.UPPER_CAMEL, v) == CommonRules.CreatedImageTypes.Docker.name){
  			setVariableDockerImageTag(variableMap, pkg.imageDescription.imageTags.values)
  		}
  	}
  }

	def fillVaribalesFromCiSetting(
  	Map<String, String> variableMap,
  	CISetting setting,
  	EList<String> distros
  ){
		setVariableROSDistros(variableMap, setting.reqBranchPrefix, distros)
  }
  
	def setVariableROSDistros(Map<String, String> variableMap,  EList<String> distros){
  	if(distros.length == 1){
  		variableMap.put("ROS_DISTRO", distros.get(0))
  	}
  }
  
	def setVariableROSDistros(Map<String, String> variableMap, String branchPrefixType, EList<String> distros){
  	if(branchPrefixType.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosDistro.name))){
	  	variableMap.put("ROS_DISTROS",
  		distros.stream()
      .collect(Collectors.joining(" "))
  		)
  		variableMap.put("ROS_DISTRO", '""')
  	}
  	if(branchPrefixType.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosVersion.name))){
	  	variableMap.put("DEFAULT_ROS_DISTROS",
  		distros.stream()
      .collect(Collectors.joining(" "))
  		)
  	}
  }
	
	def getAllRosDistros(BuildRequirements req){
		val rosVersions = DeployModelUtils.enumToList(CommonRules.RosVersions)
		val rosDistros = DeployModelUtils.enumToList(CommonRules.RosDistros)
		var distros = newArrayList()
		if(req.reqTestRosDistros !== null){
			for(distro: req.reqTestRosDistros.values){
				if(rosVersions.contains(distro)){
					distros.addAll(CommonRules.RosDistros.getRosDistrosByVersionToString(distro))
				}
				if(rosDistros.contains(distro)){
					distros.add(distro)
				}
			}
		}
		var buildDistros = req.reqRosDistros.values
		for (x : buildDistros){
	   if (!distros.contains(x))
	      distros.add(x);
		}
		return distros
	}
	
	def setRosDistroMatrix(List<String> rosDistross)'''
  parallel:
    matrix:
      - ROS_DISTRO:
      	«FOR distro: rosDistross»
      	- «distro»
      	«ENDFOR»
	'''
  
	def setVariablePrivateRepoToken(Map<String, String> variableMap, String visibility){
  	if(visibility == CommonRules.RepoVisibility.Privat.name){
  		variableMap.put('ROSINSTALL_CI_JOB_TOKEN', '"true"')
  	}
  }

	def setVariableDockerImageTag(Map<String, String> variableMap, EList<String> tagTypes){
  	for(tag: tagTypes){
  		var tag_camel = CaseFormat.UPPER_UNDERSCORE.to(CaseFormat.UPPER_CAMEL, tag);
  		if(tag_camel == CommonRules.ImageTagTypes.Branch.name){
  			variableMap.put('TARGET_BRANCH', '"${CI_REGISTRY_IMAGE}/${NAME}:${CI_COMMIT_REF_NAME//\\//-}"')
  			}
			if(tag_camel == CommonRules.ImageTagTypes.Latest.name){
  			variableMap.put('TARGET_LATEST', '"${CI_REGISTRY_IMAGE}/${NAME}:latest"')
  			}
			if(tag_camel == CommonRules.ImageTagTypes.CommitTag.name){
  			variableMap.put('TARGET_RELEASE', '"${CI_REGISTRY_IMAGE}/${NAME}:${CI_COMMIT_TAG//\\//-}"')
  		}
  	}
  }

	def setVariableDockerTLS(Map<String, String> variableMap, String TLSPath){
  	variableMap.put('DOCKER_TLS_CERTDIR', String.format('"%s"',TLSPath))
  }

	def setVariableCMakeArgs(Map<String, String> variableMap, EList<String> args){
  	variableMap.put('CMAKE_ARGS', args.stream()
      .collect(Collectors.joining(" -", '"-', '"')))
  }

	def addVariables(Map<String, String> variableMap, MonolithicImplementationDescription monImpl)'''
	«{ fillVaribalesFromMonImpl(variableMap, monImpl); "" }»
	variables:
	«FOR variable: variableMap.keySet()»
	«"  "»«variable»: «variableMap.get(variable)»
	«ENDFOR»
	
  '''

	def addVariables(Map<String, String> variableMap,
  	MonolithicImplementationDescription monImpl,
  	PackageDescription pkgDes
  )'''
	«{ fillVaribalesFromMonImpl(variableMap, monImpl); "" }»
	«{ fillVaribalesFromPackage(variableMap, pkgDes); "" }»
	variables:
	«FOR variable: variableMap.keySet()»
	«"  "»«variable»: «variableMap.get(variable)»
	«ENDFOR»
	
	'''
	
	def addVariables(Map<String, String> variableMap,
  	MonolithicImplementationDescription monImpl,
  	PackageDescription pkgDes,
  	CISetting ci
  )'''
	«{ fillVaribalesFromMonImpl(variableMap, monImpl); "" }»
	«{ fillVaribalesFromPackage(variableMap, pkgDes); "" }»
	«{ fillVaribalesFromCiSetting(variableMap, ci, monImpl.implementation.buildRequirements.reqRosDistros.values); "" }»
	variables:
	«FOR variable: variableMap.keySet()»
	«"  "»«variable»: «variableMap.get(variable)»
	«ENDFOR»
	
	'''

	/*****************************************************/
	/*
	 * fill .common block
	 */
	def addCommonBlock(
		PackageDescription pkg,
		CISetting setting
	)
'''
.common:
  docker_login_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
«FOR ciParam: setting.ciParameters»
	«IF ciParam.type == DeployModelUtils.camelToLowerUnderscore(CommonRules.RepoTypes.Gitlab.name)»
	«FOR param: ciParam.parameters»
		«IF param.type == DeployModelUtils.camelToLowerUnderscore(CommonRules.GitlabParameters.Services.name)»
		«setPropertyLabels(param)»
		«ENDIF»
		«IF param.type == DeployModelUtils.camelToLowerUnderscore(CommonRules.GitlabParameters.Tags.name)»
		«setPropertyLabels(param)»
		«IF dockerRunnerSaveCacheFlag == false»
			«{ dockerRunnerSaveCacheFlag = findTargetParameter(param, GitlabDefaultRunnerTags.DockerRunnerSaveCache.name); "" }»
		«ENDIF»
		«IF dockerRunnerNoCacheFlag == false»
			«{ dockerRunnerNoCacheFlag = findTargetParameter(param, GitlabDefaultRunnerTags.DockerRunnerNoCache.name); "" }»
		«ENDIF»
		«IF simpleRunnerFlag == false»
			«{ simpleRunnerFlag = findTargetParameter(param, GitlabDefaultRunnerTags.SimpleRunner.name); "" }»
		«ENDIF»
		«ENDIF»
	«ENDFOR»
	«ENDIF»
«ENDFOR»
«IF !setting.reqBranchPrefix.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosVersion.name))»
«var rules = collectRules(pkg.imageDescription.imageTags.values, setting.reqBranchPrefix)»
  «IF rules.size > 0»
«"  "»rules:
  	«FOR rule : rules»
«"    "»- if: «rule»
  	«ENDFOR»
	«ENDIF»
«ENDIF»

	'''
	
	def collectRules(EList<String> tagTypes, String branchPrefix){
		var rules = newArrayList()
  	for(tag: tagTypes){
  		var tag_camel = DeployModelUtils.lowerUnderscoreToCamel(tag);
			if(tag_camel == CommonRules.ImageTagTypes.CommitTag.name){
  			rules.add("&commit_tag '$CI_COMMIT_TAG != null'")
  		}
  	}
  	if (branchPrefix == BranchPrefixTypes.RosDistro){
  		rules.add("&merge_into_devel '$CI_COMMIT_REF_NAME =~ /devel/'")
  	}
  	return rules
	}
	
	def getPropertyValues(Object object){
		if (object.class == CommonPropertySingleValueImpl){
			val v = newArrayList((object as CommonPropertySingleValueImpl).value)
			val List<String> l = v
			return l
		}
		if(object.class == CommonPropertyMultiValueImpl){
			val List<String> l = (object as CommonPropertyMultiValueImpl).value.values
			return l
		}
	}
	
	def setPropertyLabels(GroupedProperties properties)
'''
«FOR p: properties.properties»
«"  "»«properties.type»: &«p.name»
«FOR v: p.propertyValues»
«"    "»- «v»
«ENDFOR»
«ENDFOR»
'''

	def findTargetParameter(GroupedProperties properties, String target){
		for(p: properties.properties){
			if(p.name.equals(DeployModelUtils.camelToLowerUnderscore(target))){
				return true
			}
		}
		return false
	}
	
	def findRosDistroFromBranchPrefix()'''
prepare:
  stage: check_ros_distro
  «IF simpleRunnerFlag»
  tags: *«DeployModelUtils.camelToLowerUnderscore(GitlabDefaultRunnerTags.SimpleRunner.name())»
 	«ELSEIF dockerRunnerSaveCacheFlag»
  tags: *«DeployModelUtils.camelToLowerUnderscore(GitlabDefaultRunnerTags.DockerRunnerSaveCache.name())»
  «ELSEIF dockerRunnerNoCacheFlag»
    tags: *«DeployModelUtils.camelToLowerUnderscore(GitlabDefaultRunnerTags.DockerRunnerNoCache.name())»
 	«ENDIF»
  script:
    - |
      for distro in $ROS_DISTROS; do
        raw=${CI_COMMIT_REF_NAME//\//-}
        if [[ "$distro" = "${raw%%-*}" ]] || [[ "$distro" = "${CI_COMMIT_REF_NAME}" ]] || [[ "$distro" = "${raw%%_*}" ]]; then
          echo "found"
          echo "ROS_DISTRO=$distro" >> build.env
          break
        fi
      done;
      if [[ $ROS_DISTRO = "" ]]; then
        exit 1
        echo "Not found"
      fi
  artifacts:
    reports:
      dotenv: build.env

'''

	def commonBuild()'''
.build:
  stage: ${CI_JOB_NAME}
  «IF dockerRunnerNoCacheFlag || dockerRunnerSaveCacheFlag »
    services: *docker_service
    tags: *docker_runner
  «ENDIF»
  before_script:
    - !reference [.common, docker_login_script]
    - echo "CI_PIPELINE_SOURCE=$CI_PIPELINE_SOURCE"
  script:
    - >
      TARGET=${CI_REGISTRY_IMAGE}/${NAME}:${CI_COMMIT_REF_NAME//\//-};
      docker build --cache-from $TARGET --cache-from $TARGET_LATEST --cache-from $TARGET_BRANCH
      --build-arg SUFFIX
      --build-arg PREFIX
      --build-arg BUILDER_PREFIX
      --build-arg BUILDER_SUFFIX
      --build-arg ROS_DISTRO
      --build-arg ROSINSTALL_CI_JOB_TOKEN=$ROSINSTALL_CI_JOB_TOKEN
      --build-arg CI_JOB_TOKEN=$CI_JOB_TOKEN
      --build-arg BUILDKIT_INLINE_CACHE=1
      --build-arg CMAKE_ARGS
      -t ${PREFIX}${NAME}${SUFFIX} ${FOLDER}
     «IF dockerRunnerSaveCacheFlag »«ELSE»
     - docker push ${PREFIX}${NAME}${SUFFIX}
     «ENDIF»
  needs:
    - prepare
  variables:
    NAME: ${CI_JOB_NAME}_${ROS_DISTRO}

	''' 
	
	def findRosVersion(List<String> distros){
		var versions = newHashSet
			for(distro: distros){
				if(CommonRules.RosDistros.getRosVersion(CommonRules.RosDistros.valueOf(DeployModelUtils.lowerUnderscoreToCamel(distro))) 
					== CommonRules.RosVersions.Ros1
				){
					versions.add(DeployModelUtils.camelToLowerUnderscore(CommonRules.RosVersions.Ros1.name))
				}
				if(CommonRules.RosDistros.getRosVersion(CommonRules.RosDistros.valueOf(DeployModelUtils.lowerUnderscoreToCamel(distro))) 
					== CommonRules.RosVersions.Ros2
				){
					versions.add(DeployModelUtils.camelToLowerUnderscore(CommonRules.RosVersions.Ros2.name))
				}
			}
		return versions
	}
	
	def filterRosDistros(List<String> distros, String version){
		var res = newHashSet
			for(distro: distros){
				if(CommonRules.RosDistros.getRosVersion(CommonRules.RosDistros.valueOf(DeployModelUtils.lowerUnderscoreToCamel(distro))) 
					== CommonRules.RosVersions.valueOf(DeployModelUtils.lowerUnderscoreToCamel(version))
				){
					res.add(distro)
				}
			}
		return res
	}
	
	def build(MonolithicImplementationDescription monImpl,
	  	CISetting ci)'''
	«var reqDistros = getAllRosDistros(monImpl.implementation.buildRequirements)»
	«var reqVersions = findRosVersion(reqDistros)»
	«IF ci.reqBranchPrefix.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosVersion.name))»
	«FOR version : reqVersions»	
	«monImpl.name»:«version»:
	  extends:
	    - .build
	    «IF ci.reqBranchPrefix.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosVersion.name))»
	    - .on_«version»
	    «ENDIF»
	  variables:
	    NAME: «monImpl.name»_${ROS_DISTRO}
	    FOLDER: "«monImpl.implementation.location»"
	  «setRosDistroMatrix(filterRosDistros(reqDistros, version).toList)»
	«»
	«ENDFOR»
	«ENDIF»
	
	'''
	
	def commonPublish()'''
.publish:
  stage: publish
«IF dockerRunnerNoCacheFlag || dockerRunnerSaveCacheFlag »
«  »services: *docker_service
«  »tags: *docker_runner
«ENDIF»
  before_script:
    - !reference [.common, docker_login_script]
   «IF dockerRunnerSaveCacheFlag »«ELSE»
   - docker pull ${PREFIX}${NAME}${SUFFIX}
   «ENDIF»
  script:
    - |
      TARGET=${CI_REGISTRY_IMAGE}/${NAME}:${CI_COMMIT_REF_NAME//\//-}
      if [ "$CI_COMMIT_REF_NAME" = "main" ]; then
        TARGET=$TARGET_LATEST
      fi
      if [ "$CI_COMMIT_REF_NAME" = "${ROS_DISTRO}/devel" ]; then
        TARGET=$TARGET_LATEST
      fi
      if [ $CI_COMMIT_TAG ]; then
        convert_tag=${CI_COMMIT_TAG//\//-}
        distro_prefix=${ROS_DISTRO}-
        remove_distro_tag=${convert_tag#"$distro_prefix"}
        TARGET_RELEASE=${CI_REGISTRY_IMAGE}/${NAME}:${remove_distro_tag}
        TARGET=$TARGET_RELEASE
      fi
      docker tag ${PREFIX}${NAME}${SUFFIX} ${TARGET} && docker push ${TARGET}
  needs:
    - build

	'''
	
	def publish(MonolithicImplementationDescription monImpl,
		PackageDescription pkg,
		CISetting ci
	)'''
«var reqDistros = getAllRosDistros(monImpl.implementation.buildRequirements)»
«var reqVersions = findRosVersion(reqDistros)»
«IF ci.reqBranchPrefix.equals(DeployModelUtils.camelToLowerUnderscore(CommonRules.BranchPrefixTypes.RosVersion.name))»
«FOR version : reqVersions»	
publish:«monImpl.name»:«version»:
  extends:
    - .publish
  «IF pkg.imageDescription.imageTags.values.contains(DeployModelUtils.camelToLowerUnderscore(CommonRules.ImageTagTypes.CommitTag.name))»
    «IF pkg.imageDescription.imageTags.values.contains(DeployModelUtils.camelToLowerUnderscore(CommonRules.ImageTagTypes.Latest.name))»
    - .on_«version»_merge_tag
    «ELSE»
    - .on_«version»_tag
    «ENDIF»
    «ELSE»
    «IF pkg.imageDescription.imageTags.values.contains(DeployModelUtils.camelToLowerUnderscore(CommonRules.ImageTagTypes.Latest.name))»
    - .on_«version»_merge
  «ELSE»
    - .on_«version»
    «ENDIF»
  «ENDIF»
  variables:
    NAME: «monImpl.name»_${ROS_DISTRO}
  needs:
    - «monImpl.name»:«version»
  «setRosDistroMatrix(filterRosDistros(reqDistros, version).toList)»
«»
«ENDFOR»
«ENDIF»

	'''
	
	def compileRules(MonolithicImplementationDescription monImpl)'''
  variables:
    ROS2_DEV_BRANCH: ros2/devel
    ROS1_DEV_BRANCH: ros1/devel
    ROS2_PREFIX: ros2
    ROS1_PREFIX: ros1

  .on_ros2:
    rules:
      - !reference [.rules-map, not_ros2_branch]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros1:
    rules:
      - !reference [.rules-map, not_ros1_branch]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros2_tag:
    rules:
      - !reference [.rules-map, not_ros2_branch]
      - !reference [.rules-map, not_commit_tag]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros1_tag:
    rules:
      - !reference [.rules-map, not_ros1_branch]
      - !reference [.rules-map, not_commit_tag]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros2_merge:
    rules:
      - !reference [.rules-map, not_ros2_branch]
      - !reference [.rules-map, not_merge_into_ros2_devel]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros1_merge:
    rules:
      - !reference [.rules-map, not_ros1_branch]
      - !reference [.rules-map, not_merge_into_ros1_devel]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros2_merge_tag:
    rules:
      - !reference [.rules-map, not_ros2_branch]
      - !reference [.rules-map, not_merge_into_ros2_devel_and_tag]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .on_ros1_merge_tag:
    rules:
      - !reference [.rules-map, not_ros1_branch]
      - !reference [.rules-map, not_merge_into_ros1_devel_and_tag]
      - !reference [.rules-map, allow_failure_distros]
      - !reference [.rules-map, not_allow_failure_distros]

  .rules-map:
    ros2_branch:
      - if: $CI_COMMIT_REF_NAME =~ /ros2/
        when: on_success
    not_ros2_branch:
      - if: $CI_COMMIT_REF_NAME !~ /^ros2.*/
        when: never
    not_ros1_branch:
      - if: $CI_COMMIT_REF_NAME !~ /^ros1.*/
        when: never
    allow_failure_distros:
      - if: $ROS_DISTRO !~ $DEFAULT_ROS_DISTROS
        when: on_success
        allow_failure: true
    not_allow_failure_distros:
      - if: $ROS_DISTRO =~ $DEFAULT_ROS_DISTROS
        when: on_success
        allow_failure: false
    not_merge_into_ros1_devel:
      - if: $CI_COMMIT_BRANCH != $ROS1_DEV_BRANCH
        when: never
    not_merge_into_ros2_devel:
      - if: $CI_COMMIT_BRANCH != $ROS2_DEV_BRANCH
        when: never
    not_merge_into_ros2_devel_and_tag:
      - if: $CI_COMMIT_BRANCH != $ROS2_DEV_BRANCH && $CI_COMMIT_TAG == null
        when: never
    not_merge_into_ros1_devel_and_tag:
      - if: $CI_COMMIT_BRANCH != $ROS1_DEV_BRANCH && $CI_COMMIT_TAG == null
        when: never
    commit_tag:
      - if: $CI_COMMIT_TAG != null
        when: on_success
    not_commit_tag:
      - if: $CI_COMMIT_TAG == null
        when: never

	'''
	
}
