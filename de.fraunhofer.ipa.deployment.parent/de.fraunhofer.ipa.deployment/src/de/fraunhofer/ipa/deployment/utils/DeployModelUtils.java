package de.fraunhofer.ipa.deployment.utils;

import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import com.google.common.base.CaseFormat;

public class DeployModelUtils {
	public static String camelToLowerUnderscore(String s){
		return CaseFormat.UPPER_CAMEL.to(CaseFormat.LOWER_UNDERSCORE, s);
	}
	
	public static String lowerUnderscoreToCamel(String s) {
		return CaseFormat.LOWER_UNDERSCORE.to(CaseFormat.UPPER_CAMEL, s);
	}
	
    public static <T> Set<T> findDuplicates(List<T> list)
    {
        Set<T> seen = new HashSet<>();
        return list.stream()
                .filter(e -> !seen.add(e))
                .collect(Collectors.toSet());
    }
    
    public static <E extends Enum<E>> List<String> enumToList(Class<E> enumClass) {
    	List<String> distroList = (List<String>) EnumSet.allOf(enumClass).
				stream().
				map(e -> camelToLowerUnderscore(e.name())).
				collect(Collectors.toList());
    	return distroList;
	}
}
