package org.checkerframework.checker.test.junit.ainferrunners;

import org.checkerframework.checker.testchecker.ainfer.AinferTestChecker;
import org.checkerframework.framework.test.AinferValidatePerDirectoryTest;
import org.junit.experimental.categories.Category;
import org.junit.runners.Parameterized.Parameters;

import java.io.File;
import java.util.List;

/**
 * Tests whole-program type inference with the aid of .jaif files. This test is the second pass,
 * which ensures that with the annotations inserted, the errors are no longer issued.
 */
@Category(AinferTestCheckerJaifsTest.class)
public class AinferTestCheckerJaifsValidationTest extends AinferValidatePerDirectoryTest {
    /**
     * @param testFiles the files containing test code, which will be type-checked
     */
    public AinferTestCheckerJaifsValidationTest(List<File> testFiles) {
        super(
                testFiles,
                AinferTestChecker.class,
                "testchecker",
                "ainfer-testchecker/non-annotated",
                AinferTestCheckerJaifsTest.class,
                "-Awarns",
                // The AFU's JAIF reading/writing libraries don't support records.
                "-AskipDefs=TestPure|SimpleRecord");
    }

    @Parameters
    public static String[] getTestDirs() {
        return new String[] {"ainfer-testchecker/annotated/"};
    }
}
