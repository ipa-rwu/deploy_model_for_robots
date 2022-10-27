package de.fraunhofer.ipa.deployment.validation;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import de.fraunhofer.ipa.deployment.utils.DeployModelUtils;

public class CommonRules {
	public enum ImageTagTypes {
	    Branch
	    ,CommitTag
	    ,Latest
		}
		
	public enum CreatedImageTypes {
	    Docker
	    ,Snap
	    ,Debian
		}
		
	public enum RepoVisibility {
	    Privat
	    ,Public
		}
		
	public enum DeploymentRequirementTypes{
			OS,
			ProcessorArchitecture
		}
		
	public enum ResourceRequirementTypes{
		  CPU
		  ,Memory
		  ,MemorySawp
		  ,OomKillDisable
		}
		
	public enum ProcessorArchitectureTypes{
		  arm64
	  	,x86
		}

	public enum OperatingSystemTypes{
		  Ubuntu18
		  ,Ubuntu20
		}

	public enum RepoTypes{
		  Gitlab
		  ,Github
		}
		
	public enum GitlabRunnerServices{
		  DockerService
		}
		
	public enum GitlabParameters{
		  Services,
		  Tags
		}
		
	public enum GitlabDefaultRunnerTags{
		  DockerRunnerNoCache,
		  DockerRunnerSaveCache,
		  SimpleRunner
		}
		
	public enum GitlabDefaultRunnerService{
		  DockerService
		}
		
	public enum RosVersions{
			Ros1
			,Ros2
		}
		
	public enum RosDistros{
		Noetic(RosVersions.Ros1),
		Melodic(RosVersions.Ros1),
		Kinetic(RosVersions.Ros1),
		Foxy(RosVersions.Ros2),
		Galactic(RosVersions.Ros2),
		Rolling(RosVersions.Ros2),
		Humble(RosVersions.Ros2);
			
		RosVersions rosVersion;

		RosDistros(RosVersions rosVersion) {
	      this.rosVersion = rosVersion;
	      }
	   
		public static RosVersions getRosVersion(RosDistros distro) {
			return distro.rosVersion;
		}
		
		public static void  display(int model){
			RosDistros constants[] = RosDistros.values();
	      System.out.println("The ros version of: "+constants[model]+" is "+constants[model].rosVersion);
	      }
		
		public static List<RosDistros>  getRosDistrosByVersion(String version){
			List<RosDistros> distros = new ArrayList<RosDistros>();
			for(RosDistros distro: RosDistros.values()) {
				if(distro.rosVersion == RosVersions.valueOf(DeployModelUtils.lowerUnderscoreToCamel(version))) {
					distros.add(distro);
				}
			}
	      return distros;
	      }
		
		public static List<String>  getRosDistrosByVersionToString(String version){
			List<RosDistros> distroEnums = getRosDistrosByVersion(version);
			List<String> distros = distroEnums.stream().
					map(e -> DeployModelUtils.camelToLowerUnderscore(e.name())).
					collect(Collectors.toList());
	      return distros;
	      }
	}
	
	public enum BranchPrefixTypes {
		None,
		RosVersion,
		RosDistro
	}
}
