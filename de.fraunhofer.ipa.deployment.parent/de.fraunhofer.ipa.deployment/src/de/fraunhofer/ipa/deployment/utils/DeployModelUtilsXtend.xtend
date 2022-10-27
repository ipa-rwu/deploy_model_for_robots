package de.fraunhofer.ipa.deployment.utils

import de.fraunhofer.ipa.deployment.deployModel.impl.CommonPropertySingleValueImpl
import java.util.List
import de.fraunhofer.ipa.deployment.deployModel.impl.CommonPropertyMultiValueImpl

class DeployModelUtilsXtend {

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
}