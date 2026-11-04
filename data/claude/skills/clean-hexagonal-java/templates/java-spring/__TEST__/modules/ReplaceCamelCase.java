package {{BASE_PACKAGE}}.modules;

import org.junit.jupiter.api.DisplayNameGenerator;

import java.lang.reflect.Method;

public class ReplaceCamelCase extends DisplayNameGenerator.Standard {

    @Override
    public String generateDisplayNameForClass(Class<?> testClass) {
        return replaceCamelCase(renameClass(super.generateDisplayNameForClass(testClass)));
    }

    private String renameClass(String testClassName) {
        if (testClassName.contains("E2ETest")) {
            return "[e2e]" + testClassName.replace("E2E", "");
        }

        if (testClassName.contains("UnitTest")) {
            return "[unit]" + testClassName.replace("Unit", "");
        }

        if (testClassName.contains("RestControllerTest")) {
            return "[rest api]" + testClassName.replace("RestController", "");
        }

        return "[integration]" + testClassName.replace("Integration", "");
    }

    @Override
    public String generateDisplayNameForNestedClass(Class<?> nestedClass) {
        return replaceCamelCase(super.generateDisplayNameForNestedClass(nestedClass));
    }

    @Override
    public String generateDisplayNameForMethod(Class<?> testClass, Method testMethod) {
        return this.replaceCamelCase(testMethod.getName()) +
                DisplayNameGenerator.parameterTypesAsString(testMethod);
    }

    String replaceCamelCase(String camelCase) {
        StringBuilder result = new StringBuilder();
        result.append(camelCase.charAt(0));
        for (int i = 1; i < camelCase.length(); i++) {
            if (Character.isUpperCase(camelCase.charAt(i))) {
                result.append(' ');
                result.append(Character.toLowerCase(camelCase.charAt(i)));
            } else {
                result.append(camelCase.charAt(i));
            }
        }
        return result.toString();
    }
}
