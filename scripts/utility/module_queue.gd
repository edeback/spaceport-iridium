class_name ModuleQueue
extends Object

class QueueElement:
	var vertex: ModuleGraphVertex
	var cost: float
	func _init(v: ModuleGraphVertex, c: float) -> void:
		self.vertex = v
		self.cost = c

var _data: Array[QueueElement] = []

func insert(vertex: ModuleGraphVertex, cost: float) -> void:
	# Add the element to the bottom level of the heap at the leftmost open space
	self._data.push_back(QueueElement.new(vertex, cost))
	var new_element_index: int = self._data.size() - 1
	self._up_heap(new_element_index)

func extract() -> ModuleGraphVertex:
	if self.is_empty():
		return null
	var result: QueueElement = self._data.pop_front()
	# If the tree is not empty, replace the root of the heap with the last
	# element on the last level.
	if not self.is_empty():
		self._data.push_front(self._data.pop_back())
		self._down_heap(0)
	return result.vertex

func is_empty() -> bool:
	return self._data.is_empty()

func _get_parent(index: int) -> int:
	@warning_ignore("integer_division")
	return (index - 1) / 2

func _left_child(index: int) -> int:
	return (2 * index) + 1

func _right_child(index: int) -> int:
	return (2 * index) +  2

func _swap(a_idx: int, b_idx: int) -> void:
	var a := self._data[a_idx]
	var b := self._data[b_idx]
	self._data[a_idx] = b
	self._data[b_idx] = a

func _up_heap(index: int) -> void:
	# Compare the added element with its parent; if they are in the correct order, stop.
	var parent_idx := self._get_parent(index)
	if self._data[index].cost >= self._data[parent_idx].cost:
		return
	self._swap(index, parent_idx)
	self._up_heap(parent_idx)

func _down_heap(index: int) -> void:
	var left_idx: int = self._left_child(index)
	var right_idx: int = self._right_child(index)
	var smallest: int = index
	var size: int = self._data.size()

	if right_idx < size and self._data[right_idx].cost < self._data[smallest].cost:
		smallest = right_idx

	if left_idx < size and self._data[left_idx].cost < self._data[smallest].cost:
		smallest = left_idx

	if smallest != index:
		self._swap(index, smallest)
		self._down_heap(smallest)
