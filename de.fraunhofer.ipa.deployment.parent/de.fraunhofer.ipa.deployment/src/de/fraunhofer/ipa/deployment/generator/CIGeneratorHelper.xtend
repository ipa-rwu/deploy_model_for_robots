package de.fraunhofer.ipa.deployment.generator


class CIGeneratorHelper {
	def setEnvVaribalesCommon(){
		val envVaribales = #[
		'SUFFIX',
		'PREFIX',
		'BUILDER_PREFIX',
		'BUILDER_SUFFIX',
		'FOLDER',
		'NAME'
		]
		return envVaribales
	}

	def setEnvVaribalesAccessGitlabRepo(Boolean privateGitlabRepo){
		var envVaribales = newArrayList()
		if(privateGitlabRepo){
			envVaribales.add('ROSINSTALL_CI_JOB_TOKEN')
		}
		return envVaribales
	}

	def setEnvVaribalesUnreleasedDep(Boolean UnreleasedDep){
		var envVaribales = newArrayList()
		if(UnreleasedDep){
			envVaribales.add('UNRELEASED_DEP_PREFIX')
			envVaribales.add('UNRELEASED_DEP_SUFFIX')
		}
		return envVaribales
	}

	def setEnvVaribalesROSDistro(Boolean useBranchPrefix){
		var envVaribales = newArrayList('ROS_DISTRO')
		if (useBranchPrefix){
				envVaribales.add('ROS_DISTROS')
		}
		return envVaribales
	}


	def setEnvVaribalesDockerTLS(){
			val envVaribales = #[
			'DOCKER_TLS_CERTDIR'
		]
		return envVaribales
	}

}
