<?php

final class InboxUncrustifyLinter extends ArcanistLinter {
	
	public function willLintPaths(array $paths) {
		$script = $this->getConfiguredScript();
		$root   = $this->getEngine()->getWorkingCopy()->getProjectRoot();
	
		$futures = array();
		foreach ($paths as $path) {
		  $future = new ExecFuture('%C %s', $script, $path);
		  $future->setCWD($root);
		  $futures[$path] = $future;
		}
	
		foreach (Futures($futures)->limit(4) as $path => $future) {
		  list($stdout) = $future->resolvex();
		  $this->output[$path] = $stdout;
		}
	}
	
	public function getLinterName() {
		return "Inbox Uncrustify Linter";
	}
	
	public function lintPath($path) {
// Not necessary to do anything because uncrustify writes directly stderr when there's a problem

// 	 $dict = array(
//         'path'          => idx($match, 'file', $path),
//         'line'          => $line,
//         'char'          => $char,
//         'code'          => idx($match, 'code', $this->getLinterName()),
//         'severity'      => $this->getMatchSeverity($match),
//         'name'          => idx($match, 'name', 'Lint'),
//         'description'   => idx($match, 'message', 'Undefined Lint Message'),
//       );
// 
//       $original = idx($match, 'original');
//       if ($original !== null) {
//         $dict['original'] = $original;
//       }
// 
//       $replacement = idx($match, 'replacement');
//       if ($replacement !== null) {
//         $dict['replacement'] = $replacement;
//       }
// 
//       $lint = ArcanistLintMessage::newFromDictionary($dict);
//       $this->addLintMessage($lint);
	 }
	  
	 private function getConfiguredScript() {
		$key = 'lint.uncrustify.script';
		$config = $this->getEngine()
		  ->getConfigurationManager()
		  ->getConfigFromAnySource($key);
	
		if (!$config) {
		  throw new ArcanistUsageException(
			"InboxUncrustifyLinter: ".
			"You must configure '{$key}' to point to an uncrustify script to execute.");
		}
	
		// NOTE: No additional validation since the "script" can be some random
		// shell command and/or include flags, so it does not need to point to some
		// file on disk.
	
		return $config;
	}
}
  
?>