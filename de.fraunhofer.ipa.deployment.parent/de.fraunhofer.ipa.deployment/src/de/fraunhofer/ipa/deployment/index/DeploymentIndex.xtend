package de.fraunhofer.ipa.deployment.index

import com.google.common.collect.Iterables
import com.google.common.collect.Lists
import java.util.List
import javax.inject.Inject
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescription.Event.Source
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.scoping.impl.DelegatingEventSource
import org.eclipse.xtext.util.OnChangeEvictingCache

class DeploymentIndex {
	@Inject
  extension ResourceDescriptionsProvider indexProvider

	
	
	@Inject
	IContainer.Manager containerManager

	@Inject
	IResourceDescription.Manager descriptionManager;

//	def getEntity(QualifiedName qualifiedName, EObject context) {
//		context.getVisibleEObjectsByType(DeployModelPackage.Literals.MONOLITHIC_IMPLEMENTATION_DESCRIPTION).
//		findFirst[it.qualifiedName == qualifiedName]
//	}
//
	def getVisibleEObjectsByTypeCrossProjets(
		Iterable<IResourceDescription> allResourceDescriptions,  EClass type) {
		allResourceDescriptions.map[getExportedObjectsByType(type)]
	}
	
	//	allResourceDescriptions = getAllResourceDescriptions from IResourceDescriptions
	def getReferenceDescriptionsCrossProjets(Iterable<IResourceDescription> allResourceDescriptions){
		allResourceDescriptions.map[getReferenceDescriptions]
	}
	
	def getCurrentResouceVisibleEObjectsByType(Resource context, EClass type) {
			val index = indexProvider.getResourceDescriptions(context)
			val resourceDescription = index.getResourceDescription(context.URI)
			resourceDescription.getExportedObjectsByType(type)
		}
	
	def getMachedEntity(Resource context, EClass type, QualifiedName qName) {
			context.getVisibleEObjectsByType(type).filter[it.qualifiedName.equals(qName)]?.head
		}
	
	def getVisibleEObjectsByType(Resource context, EClass type) {
		context.visibleContainers.map[getExportedObjectsByType(type)].flatten
	}

	def protected String getCacheKey(String base, ResourceSet context) {
		var loadOptions = context.getLoadOptions();
		if (loadOptions.containsKey(ResourceDescriptionsProvider.NAMED_BUILDER_SCOPE)) {
			return base + "@" + ResourceDescriptionsProvider.NAMED_BUILDER_SCOPE;
		} 
		return base + "@DEFAULT_SCOPE"; 
	}

		// 	Containers from the same project	
	 def getVisibleContainers(Resource resource) {
		var description = descriptionManager.getResourceDescription(resource)
		var resourceDescriptions = getResourceDescriptions(resource)
		var cacheKey = getCacheKey("VisibleContainers", resource.getResourceSet())
		var cache = new OnChangeEvictingCache().getOrCreate(resource)
		var List<IContainer> result = newArrayList
		result = cache.get(cacheKey)
		if (result === null) {
			result = containerManager.getVisibleContainers(description, resourceDescriptions);
			// SZ: I'ld like this dependency to be moved to the implementation of the
			// container manager, but it is not aware of a CacheAdapter
			if (resourceDescriptions instanceof IResourceDescription.Event.Source) {
				var IResourceDescription.Event.Source eventSource = resourceDescriptions as Source;
				var DelegatingEventSource delegatingEventSource = new DelegatingEventSource(eventSource);
				delegatingEventSource.addListeners(Lists.newArrayList(Iterables.filter(result, IResourceDescription.Event.Listener)))
				delegatingEventSource.initialize()
				cache.addCacheListener(delegatingEventSource)
			}
			cache.set(cacheKey, result)
		}
		return result
	}
}