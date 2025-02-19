package org.checkerframework.dataflow.cfg.playground;

import org.checkerframework.dataflow.analysis.BackwardAnalysis;
import org.checkerframework.dataflow.analysis.BackwardAnalysisImpl;
import org.checkerframework.dataflow.analysis.UnusedAbstractValue;
import org.checkerframework.dataflow.cfg.visualize.CFGVisualizeLauncher;
import org.checkerframework.dataflow.livevariable.LiveVarStore;
import org.checkerframework.dataflow.livevariable.LiveVarTransfer;

/** The playground of live variable analysis. */
public class LiveVariablePlayground {

    /**
     * Run live variable analysis for a specific file and create a PDF of the CFG in the end.
     *
     * @param args command-line arguments, not used
     */
    public static void main(String[] args) {

        /* Configuration: change as appropriate */
        String inputFile = "Test.java"; // input file name and path
        String outputDir = "cfg"; // output directory
        String method = "test"; // name of the method to analyze
        String clazz = "Test"; // name of the class to consider

        // Run the analysis and create a PDF file
        LiveVarTransfer transfer = new LiveVarTransfer();
        BackwardAnalysis<UnusedAbstractValue, LiveVarStore, LiveVarTransfer> backwardAnalysis =
                new BackwardAnalysisImpl<>(transfer);
        CFGVisualizeLauncher.generateDOTofCFG(
                inputFile, outputDir, method, clazz, true, true, backwardAnalysis);
    }
}
