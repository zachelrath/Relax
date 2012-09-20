global virtual interface ProcessStep {
	// Set the Process that we are a part of and the Runnable to execute
	void init(Process p, Runnable r);
	// Clean up after this step, 
	// and advance to the next step in our process
	void complete(); 
}