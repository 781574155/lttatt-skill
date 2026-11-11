package com.lttatt.platform.common.config;

import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import com.lttatt.platform.common.gor.GeneralOperationResult;
import io.swagger.v3.core.converter.AnnotatedType;
import io.swagger.v3.core.converter.ModelConverters;
import io.swagger.v3.core.jackson.ModelResolver;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.media.*;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springdoc.core.customizers.PropertyCustomizer;
import org.springdoc.core.models.GroupedOpenApi;
import org.springdoc.core.providers.ObjectMapperProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.type.filter.RegexPatternTypeFilter;

import java.lang.reflect.Type;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Slf4j
@Configuration
public class OpenApiConfig {
  private static final String BEARER_AUTH = "BearerAuth";
  private static final String APPLICATION_JSON = "application/json";
  private static final String ALL_MEDIA_TYPES = "*/*";
  private static final PropertyNamingStrategies.SnakeCaseStrategy SNAKE_CASE =
      new PropertyNamingStrategies.SnakeCaseStrategy();

  @Bean
  public GroupedOpenApi adminOpenApi() {
    return GroupedOpenApi.builder()
        .group("admin")
        .pathsToMatch("/admin/**")
        .addOpenApiCustomizer(openApiCustomizer())
        .build();
  }

  @Bean
  public GroupedOpenApi internalOpenApi() {
    return GroupedOpenApi.builder()
        .group("internal")
        .pathsToMatch("/internal/**")
        .addOpenApiCustomizer(createOpenApiCustomizer(false))
        .build();
  }

  @Bean
  public OpenApiCustomizer defaultOpenApiCustomizer() {
    return openApi -> {
      var paths = openApi.getPaths();
      if (paths == null) {
        return;
      }
      paths
          .keySet()
          .removeIf(
              path ->
                  path.equals("/admin")
                      || path.startsWith("/admin/")
                      || path.equals("/internal")
                      || path.startsWith("/internal/"));

      var tags = openApi.getTags();
      if (tags != null) {
        var usedTags =
            paths.values().stream()
                .flatMap(pathItem -> pathItem.readOperations().stream())
                .map(Operation::getTags)
                .filter(Objects::nonNull)
                .flatMap(Collection::stream)
                .map(this::normalizeTag)
                .collect(Collectors.toSet());
        tags.removeIf(tag -> !usedTags.contains(normalizeTag(tag.getName())));
      }
    };
  }

  @Bean
  public OpenApiCustomizer openApiCustomizer() {
    return createOpenApiCustomizer(true);
  }

  private OpenApiCustomizer createOpenApiCustomizer(boolean wrapResponses) {
    return openApi -> {
      if (openApi.getComponents() == null) {
        openApi.setComponents(new Components());
      }
      if (wrapResponses) {
        var converters = ModelConverters.getInstance("3.1.0".equals(openApi.getOpenapi()));
        converters.read(GeneralOperationResult.class).forEach(openApi.getComponents()::addSchemas);
      }
      openApi
          .getComponents()
          .addSecuritySchemes(
              BEARER_AUTH, new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer"));
      if (openApi.getPaths() != null) {
        openApi.getPaths().values().stream()
            .flatMap(pathItem -> pathItem.readOperations().stream())
            .forEach(operation -> customizeOperation(operation, wrapResponses));
      }
    };
  }

  private void customizeOperation(Operation operation, boolean wrapResponses) {
    operation.addSecurityItem(new SecurityRequirement().addList(BEARER_AUTH));
    renameQueryParameters(operation);
    if (wrapResponses && operation.getResponses() != null) {
      operation.getResponses().forEach(
          (responseCode, response) -> {
            if ("200".equals(responseCode)) {
              customizeResponse(response);
            }
          });
    }
    if (operation.getTags() != null) {
      operation.setTags(operation.getTags().stream().map(this::normalizeTag).toList());
    }
  }

  private void renameQueryParameters(Operation operation) {
    if (operation.getParameters() == null) {
      return;
    }
    operation.getParameters().stream()
        .filter(parameter -> "query".equals(parameter.getIn()))
        .forEach(parameter -> parameter.setName(SNAKE_CASE.translate(parameter.getName())));
  }

  private void customizeResponse(ApiResponse response) {
    var content = response.getContent();
    if (content == null) {
      response.setContent(generalResultContent());
      return;
    }
    content.forEach(
        (contentType, mediaType) -> {
          if (APPLICATION_JSON.equals(contentType) || ALL_MEDIA_TYPES.equals(contentType)) {
            wrapResponseSchema(mediaType);
          }
        });
    normalizeWildcardContent(content);
  }

  private void wrapResponseSchema(MediaType mediaType) {
    var schema = mediaType.getSchema();
    if (schema instanceof ByteArraySchema || schema instanceof FileSchema || isWrapped(schema)) {
      return;
    }
    if (schema == null) {
      mediaType.setSchema(generalResultSchema());
      return;
    }
    var wrappedSchema =
        new ComposedSchema()
            .addAllOfItem(generalResultSchema())
            .addAllOfItem(new Schema<>().addProperty("data", schema));
    mediaType.setSchema(wrappedSchema);
  }

  private boolean isWrapped(Schema<?> schema) {
    return schema != null
        && StringUtils.isNotBlank(schema.get$ref())
        && schema.get$ref().contains(GeneralOperationResult.class.getSimpleName());
  }

  private void normalizeWildcardContent(Content content) {
    if (content.size() != 1 || !content.containsKey(ALL_MEDIA_TYPES)) {
      return;
    }
    var schema = content.get(ALL_MEDIA_TYPES).getSchema();
    content.remove(ALL_MEDIA_TYPES);
    content.addMediaType(
        APPLICATION_JSON, new MediaType().schema(schema));
  }

  private Content generalResultContent() {
    return new Content()
        .addMediaType(
            APPLICATION_JSON,
            new MediaType().schema(generalResultSchema()));
  }

  private Schema<?> generalResultSchema() {
    return new Schema<>()
        .$ref("#/components/schemas/" + GeneralOperationResult.class.getSimpleName());
  }

  private String normalizeTag(String tag) {
    if (!tag.contains("-")) {
      return tag;
    }
    return Arrays.stream(StringUtils.split(tag, '-'))
        .map(StringUtils::capitalize)
        .collect(Collectors.joining());
  }

  @Bean
  public static ModelResolver modelResolver(ObjectMapperProvider objectMapperProvider) {
    ModelResolver.enumsAsRef = true;
    var objectMapper = objectMapperProvider.jsonMapper().copy();
    objectMapper.setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE);
    return new ModelResolver(objectMapper);
  }

  @Bean
  public PropertyCustomizer contentMapCustomizer() {
    return (property, annotatedType) -> {
      if (annotatedType == null || annotatedType.getType() == null) {
        return property;
      }

      Type t = annotatedType.getType();

      if (t instanceof JavaType jt
          && jt.isMapLikeType()
          && Map.class.isAssignableFrom(jt.getRawClass())
          && jt.containedTypeCount() == 2
          && jt.containedType(0) != null
          && jt.containedType(1) != null
          && String.class.equals(jt.containedType(0).getRawClass())
          && Object.class.equals(jt.containedType(1).getRawClass())) {
        property.setType("object");
        property.setAdditionalProperties(Boolean.TRUE);
      }

      return property;
    };
  }

  @Bean
  public List<GroupedOpenApi> groupedOpenApiRegistrar() {
    var packages = scanPackages();
    var groupedPackages = new HashMap<String, List<String>>();
    for (var pkg : packages) {
      var groupName = pkg.substring(pkg.lastIndexOf('.') + 1);
      groupedPackages.computeIfAbsent(groupName, k -> new ArrayList<>()).add(pkg);
    }
    return groupedPackages.entrySet().stream()
        .map(entry -> newGroupedOpenApi(entry.getKey(), entry.getValue().toArray(new String[0])))
        .toList();
  }

  private Set<String> scanPackages() {
    var basePackage = "com.lttatt";
    var middlePackage = "export.type";
    var result = new HashSet<String>();

    var scanner = new ClassPathScanningCandidateComponentProvider(false);

    scanner.addIncludeFilter(new RegexPatternTypeFilter(Pattern.compile(".*")));

    var pattern =
        Pattern.compile(
            "^"
                + Pattern.quote(basePackage)
                + "(\\.[^.]+)*\\."
                + Pattern.quote(middlePackage)
                + "\\.[^.]+$");

    scanner
        .findCandidateComponents(basePackage)
        .forEach(
            bean -> {
              var className = bean.getBeanClassName();
              if (StringUtils.isBlank(className)) {
                return;
              }

              var pkg = className.substring(0, className.lastIndexOf('.'));

              if (pattern.matcher(pkg).matches()) {
                result.add(pkg);
              }
            });

    return result;
  }

  private GroupedOpenApi newGroupedOpenApi(String group, String... packagesToScan) {
    return GroupedOpenApi.builder()
        .group(group + "-types")
        .packagesToScan(packagesToScan)
        .addOpenApiCustomizer(openApi -> registerTypeSchemas(openApi, packagesToScan))
        .build();
  }

  private void registerTypeSchemas(OpenAPI openApi, String... packagesToScan) {
    if (openApi.getComponents() == null) {
      openApi.setComponents(new Components());
    }

    var scanner = new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter((metadataReader, metadataReaderFactory) -> true);

    var registeredSchemaNames = new LinkedHashSet<String>();
    for (String packageName : packagesToScan) {
      scanner
          .findCandidateComponents(packageName)
          .forEach(
              candidate ->
                  registerTypeSchema(
                      openApi, registeredSchemaNames, packageName, candidate.getBeanClassName()));
    }
  }

  private void registerTypeSchema(
      OpenAPI openApi, Set<String> registeredSchemaNames, String packageName, String className) {
    if (StringUtils.isBlank(className)) {
      return;
    }
    try {
      var schemaClass = Class.forName(className);
      if (!packageName.equals(schemaClass.getPackageName()) || schemaClass.isMemberClass()) {
        return;
      }
      var resolvedSchema =
          ModelConverters.getInstance("3.1.0".equals(openApi.getOpenapi()))
              .resolveAsResolvedSchema(new AnnotatedType(schemaClass));
      registerReferencedSchemas(openApi, registeredSchemaNames, resolvedSchema.referencedSchemas);
      registerInlineSchema(openApi, registeredSchemaNames, schemaClass, resolvedSchema.schema);
    } catch (ClassNotFoundException e) {
      log.warn("加载schema类型失败: {}", className, e);
    }
  }

  private void registerReferencedSchemas(
      OpenAPI openApi, Set<String> registeredSchemaNames, Map<String, Schema> schemas) {
    if (schemas == null) {
      return;
    }
    schemas.forEach(
        (schemaName, schema) -> addSchema(openApi, registeredSchemaNames, schemaName, schema));
  }

  private void registerInlineSchema(
      OpenAPI openApi, Set<String> registeredSchemaNames, Class<?> schemaClass, Schema<?> schema) {
    if (schema == null || schema.get$ref() != null) {
      return;
    }
    var schemaName = StringUtils.defaultIfBlank(schema.getName(), schemaClass.getSimpleName());
    addSchema(openApi, registeredSchemaNames, schemaName, schema);
  }

  private void addSchema(
      OpenAPI openApi, Set<String> registeredSchemaNames, String schemaName, Schema<?> schema) {
    if (registeredSchemaNames.add(schemaName)) {
      openApi.getComponents().addSchemas(schemaName, schema);
    }
  }
}
