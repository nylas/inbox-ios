<?php

final class InboxUncrustifyLintEngine extends ArcanistLintEngine {

  public function buildLinters() {

    // This is a list of paths which the user wants to lint. Either they
    // provided them explicitly, or arc figured them out from a commit or set
    // of changes. The engine needs to return a list of ArcanistLinter objects,
    // representing the linters which should be run on these files.
    $paths = $this->getPaths();

    $uncrustify_linter = new InboxUncrustifyLinter();

    // Remove any paths that don't exist before we add paths to linters. We want
    // to do this for linters that operate on file contents because the
    // generated list of paths will include deleted paths when a file is
    // removed.
    foreach ($paths as $key => $path) {
      if (!$this->pathExists($path)) {
        unset($paths[$key]);
      }
    }

    foreach ($paths as $path) {
      if (!preg_match('/^.*\.(m|h)$/i', $path)) {
        // This isn't a python file, so don't try to apply the PyLint linter
        // to it.
        continue;
      } else {
      	echo $path;
	  }

      // Add the path, to tell the linter it should examine the source code
      // to try to find problems.
      $uncrustify_linter->addPath($path);
    }

    // We only built one linter, but you can build more than one (e.g., a
    // Javascript linter for JS), and return a list of linters to execute. You
    // can also add a path to more than one linter (for example, if you want
    // to run a Python linter and a more general text linter on every .py file).

    return array(
      $uncrustify_linter
    );
  }

}