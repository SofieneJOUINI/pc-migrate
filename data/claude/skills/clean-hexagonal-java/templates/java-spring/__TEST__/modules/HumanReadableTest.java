package {{BASE_PACKAGE}}.modules;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayNameGeneration;
import org.junit.jupiter.api.TestInfo;

import java.lang.reflect.Method;

@DisplayNameGeneration(ReplaceCamelCase.class)
public interface HumanReadableTest {

    @BeforeEach
    default void setUp(TestInfo testInfo) {
        this.displayCurrentTestCaseName(testInfo);
    }

    private void displayCurrentTestCaseName(TestInfo testInfo) {
        if (testInfo.getTestMethod().isPresent() && testInfo.getTestClass().isPresent()) {
            final Method method = testInfo.getTestMethod().get();
            final Class<?> aClass = testInfo.getTestClass().get();
            System.out.printf(" > %s [%s::%s]%n", testInfo.getDisplayName(), aClass.getSimpleName(), method.getName());
        }
    }
}
